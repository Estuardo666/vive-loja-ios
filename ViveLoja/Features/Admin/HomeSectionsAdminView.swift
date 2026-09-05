import Observation
import SwiftUI

/// In-app editor of the home composition, for administrators.
///
/// It talks to the same `/admin/home-sections` endpoints as the web panel, so a
/// change made from a phone and one made from the browser are the same change.

@MainActor
@Observable
final class HomeSectionsAdminViewModel {
    var sections: [HomeSectionAdmin] = []
    var isLoading = false
    var errorMessage: String?

    private let accessToken: String

    init(accessToken: String) {
        self.accessToken = accessToken
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response: HomeSectionListResponse = try await APIClient.shared.get(
                "/admin/home-sections", bearer: accessToken
            )
            sections = response.sections
            errorMessage = nil
        } catch {
            errorMessage = message(for: error)
        }
    }

    func save(_ request: HomeSectionAdminRequest, editing id: String?) async -> Bool {
        do {
            let response: HomeSectionResponse
            if let id {
                response = try await APIClient.shared.patch(
                    "/admin/home-sections/\(id)", body: request, bearer: accessToken
                )
            } else {
                response = try await APIClient.shared.post(
                    "/admin/home-sections", body: request, bearer: accessToken
                )
            }
            if let index = sections.firstIndex(where: { $0.id == response.section.id }) {
                sections[index] = response.section
            } else {
                sections.append(response.section)
            }
            errorMessage = nil
            return true
        } catch {
            errorMessage = message(for: error)
            return false
        }
    }

    func setActive(_ isActive: Bool, for section: HomeSectionAdmin) async {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return }
        // Optimistic: the switch must not lag behind the network.
        sections[index].isActive = isActive
        do {
            let _: HomeSectionToggleResponse = try await APIClient.shared.patch(
                "/admin/home-sections/\(section.id)",
                body: HomeSectionToggleRequest(isActive: isActive),
                bearer: accessToken
            )
        } catch {
            sections[index].isActive = !isActive
            errorMessage = message(for: error)
        }
    }

    func delete(_ section: HomeSectionAdmin) async {
        let snapshot = sections
        sections.removeAll { $0.id == section.id }
        do {
            let _: HomeSectionDeleteResponse = try await APIClient.shared.delete(
                "/admin/home-sections/\(section.id)", body: EmptyBody(), bearer: accessToken
            )
        } catch {
            sections = snapshot
            errorMessage = message(for: error)
        }
    }

    func move(from offsets: IndexSet, to destination: Int) async {
        let snapshot = sections
        sections.move(fromOffsets: offsets, toOffset: destination)
        do {
            let response: HomeSectionListResponse = try await APIClient.shared.patch(
                "/admin/home-sections/reorder",
                body: HomeSectionReorderRequest(ids: sections.map(\.id)),
                bearer: accessToken
            )
            sections = response.sections
        } catch {
            sections = snapshot
            errorMessage = message(for: error)
        }
    }

    private func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? "No se pudo completar la acción."
    }
}

private struct EmptyBody: Codable, Sendable {}
private struct HomeSectionToggleResponse: Codable, Sendable { let id: String }
private struct HomeSectionDeleteResponse: Codable, Sendable { let id: String }

struct HomeSectionsAdminView: View {
    @Environment(SessionStore.self) private var session
    @State private var model: HomeSectionsAdminViewModel?
    @State private var editing: HomeSectionEditorView.Draft?

    var body: some View {
        Group {
            if let model {
                content(model: model)
            } else {
                ContentUnavailableView(
                    "Sesión requerida",
                    systemImage: "lock",
                    description: Text("Inicia sesión de nuevo para administrar el inicio.")
                )
            }
        }
        .navigationTitle("Pantalla de inicio")
        .task {
            if model == nil, let accessToken = session.accessToken {
                model = HomeSectionsAdminViewModel(accessToken: accessToken)
            }
            await model?.load()
        }
    }

    @ViewBuilder
    private func content(model: HomeSectionsAdminViewModel) -> some View {
        List {
            if let errorMessage = model.errorMessage {
                Section { Text(errorMessage).foregroundStyle(VLTheme.coral) }
            }

            Section {
                ForEach(model.sections) { section in
                    row(section, model: model)
                }
                .onMove { offsets, destination in
                    Task { await model.move(from: offsets, to: destination) }
                }
                .onDelete { offsets in
                    let targets = offsets.map { model.sections[$0] }
                    Task { for section in targets { await model.delete(section) } }
                }
            } header: {
                Text("Secciones")
            } footer: {
                Text("Arrastra para reordenar. Los cambios se ven en la app y en la web en cuanto se guardan.")
            }
        }
        .refreshable { await model.load() }
        .overlay { if model.isLoading && model.sections.isEmpty { ProgressView() } }
        .toolbar {
            // Reordering and deleting need edit mode; tapping a row to edit it
            // works outside it.
            ToolbarItem(placement: .topBarLeading) { EditButton() }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editing = HomeSectionEditorView.Draft()
                } label: {
                    Label("Nueva sección", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editing) { draft in
            NavigationStack {
                HomeSectionEditorView(draft: draft) { request in
                    await model.save(request, editing: draft.id)
                }
            }
        }
    }

    private func row(_ section: HomeSectionAdmin, model: HomeSectionsAdminViewModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(section.title).font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { section.isActive },
                    set: { value in Task { await model.setActive(value, for: section) } }
                ))
                .labelsHidden()
                .accessibilityLabel("Mostrar \(section.title)")
            }
            Text("\(section.typeLabel) · \(section.layoutLabel)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let summary = summary(for: section) {
                Text(summary).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { editing = HomeSectionEditorView.Draft(section: section) }
    }

    /// One line describing the filters, so the list is readable without opening
    /// every row.
    private func summary(for section: HomeSectionAdmin) -> String? {
        var parts: [String] = []
        if let categorySlug = section.params.categorySlug { parts.append(categorySlug) }
        if let slug = section.params.slug { parts.append(slug) }
        if section.params.featured == true { parts.append("destacados") }
        if let sort = section.params.sort { parts.append(sort) }
        if let window = section.params.window { parts.append(window) }
        if let limit = section.params.limit { parts.append("\(limit) items") }
        if section.platform != "all" {
            parts.append(HomeSectionCatalog.platforms.first { $0.value == section.platform }?.label ?? section.platform)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

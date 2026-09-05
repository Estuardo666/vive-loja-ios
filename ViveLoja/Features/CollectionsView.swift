import Observation
import SwiftUI

@MainActor
@Observable
final class CollectionsViewModel {
    var collections: [MobileOwnedCollection] = []
    var isLoading = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { collections = []; return }
        isLoading = true; defer { isLoading = false }
        do {
            collections = try await APIClient.shared.get("/me/collections", bearer: accessToken)
            errorMessage = nil
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus colecciones." }
    }

    func create(name: String, isPublic: Bool, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        do {
            let created: MobileOwnedCollection = try await APIClient.shared.post(
                "/me/collections",
                body: CollectionRequest(name: name, description: nil, icon: "bookmark.fill", isPublic: isPublic),
                bearer: accessToken
            )
            collections.insert(created, at: 0)
            VLFeedback.success()
            return true
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo crear la colección."; VLFeedback.error(); return false }
    }

    /// Flips a collection between private and shareable. A public collection is
    /// reachable at `/colecciones/{slug}` and by Universal Link.
    func setVisibility(_ collection: MobileOwnedCollection, isPublic: Bool, accessToken: String?) async {
        guard let accessToken else { return }
        do {
            let updated: MobileOwnedCollection = try await APIClient.shared.patch(
                "/me/collections/\(collection.id)",
                body: CollectionRequest(name: collection.name, description: collection.description, icon: collection.icon, isPublic: isPublic),
                bearer: accessToken
            )
            if let index = collections.firstIndex(where: { $0.id == updated.id }) {
                collections[index] = updated
            }
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cambiar la visibilidad."
            VLFeedback.error()
        }
    }

    /// Adds a venue, event, post or route to a collection. `CollectionItemRequest`
    /// existed but nothing ever called it, so collections could only ever be
    /// filled from the web.
    func addItem(to collectionId: String, kind: String, itemId: String, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        do {
            let updated: MobileOwnedCollection = try await APIClient.shared.post(
                "/me/collections/\(collectionId)",
                body: CollectionItemRequest(kind: kind, itemId: itemId, note: nil, order: nil),
                bearer: accessToken
            )
            if let index = collections.firstIndex(where: { $0.id == updated.id }) {
                collections[index] = updated
            }
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo agregar a la colección."
            VLFeedback.error()
            return false
        }
    }
}

struct CollectionsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = CollectionsViewModel()
    @State private var showCreate = false
    @State private var name = ""
    @State private var makePublic = false

    var body: some View {
        Group {
            if session.user == nil {
                ContentUnavailableView("Inicia sesión", systemImage: "person.crop.circle", description: Text("Crea colecciones privadas para organizar tus planes."))
            } else if model.isLoading && model.collections.isEmpty {
                ProgressView("Cargando colecciones…")
            } else if model.collections.isEmpty {
                ContentUnavailableView("Sin colecciones", systemImage: "folder", description: Text("Agrupa tus locales, eventos y rutas favoritas."))
            } else {
                List(model.collections) { collection in
                    NavigationLink(destination: CollectionDetailView(collection: collection)) {
                        HStack(spacing: 12) {
                            Image(systemName: collection.icon ?? "folder.fill").foregroundStyle(VLTheme.indigo)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name).font(.headline)
                                HStack(spacing: 6) {
                                    Text("\(collection.items.count) elementos")
                                    if collection.isPublic {
                                        Label("Pública", systemImage: "globe")
                                            .foregroundStyle(VLTheme.emerald)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if collection.isPublic {
                                ShareLink(item: AppEnvironment.current.shareURL(for: .collection, slug: collection.slug)) {
                                    Image(systemName: "square.and.arrow.up")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Compartir colección")
                            }
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            Task {
                                await model.setVisibility(
                                    collection,
                                    isPublic: !collection.isPublic,
                                    accessToken: session.accessToken
                                )
                            }
                        } label: {
                            Label(
                                collection.isPublic ? "Hacer privada" : "Hacer pública",
                                systemImage: collection.isPublic ? "lock" : "globe"
                            )
                        }
                        .tint(collection.isPublic ? .gray : VLTheme.emerald)
                    }
                }
            }
        }
        .vlScreen()
        .navigationTitle("Mis colecciones")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if session.user != nil { Button("Nueva", systemImage: "plus") { showCreate = true } } } }
        .task { await model.load(accessToken: session.accessToken) }
        .refreshable { await model.load(accessToken: session.accessToken) }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form {
                    TextField("Nombre", text: $name)
                    Toggle("Colección pública", isOn: $makePublic)
                    if makePublic {
                        Text("Cualquiera con el enlace podrá verla y guardarla.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                    .vlScreen()
                    .navigationTitle("Nueva colección")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showCreate = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Crear") { Task { if await model.create(name: name.trimmed, isPublic: makePublic, accessToken: session.accessToken) { name = ""; makePublic = false; showCreate = false } } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2) }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct CollectionDetailView: View {
    let collection: MobileOwnedCollection
    var body: some View {
        List(collection.items) { item in
            HStack(spacing: 12) {
                VLAsyncImage(url: item.venue?.image ?? item.event?.image ?? item.post?.image ?? item.route?.image, height: 62)
                    .frame(width: 82).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.venue?.name ?? item.event?.title ?? item.post?.title ?? item.route?.title ?? "Contenido")
                        .font(.headline)
                    if let note = item.note { Text(note).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .vlScreen()
        .navigationTitle(collection.name)
    }
}

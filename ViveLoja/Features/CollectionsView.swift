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

    func create(name: String, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        do {
            let created: MobileOwnedCollection = try await APIClient.shared.post("/me/collections", body: CollectionRequest(name: name, description: nil, icon: "bookmark.fill", isPublic: false), bearer: accessToken)
            collections.insert(created, at: 0)
            VLFeedback.success()
            return true
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo crear la colección."; VLFeedback.error(); return false }
    }
}

struct CollectionsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = CollectionsViewModel()
    @State private var showCreate = false
    @State private var name = ""

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
                                Text("\(collection.items.count) elementos").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Mis colecciones")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if session.user != nil { Button("Nueva", systemImage: "plus") { showCreate = true } } } }
        .task { await model.load(accessToken: session.accessToken) }
        .refreshable { await model.load(accessToken: session.accessToken) }
        .sheet(isPresented: $showCreate) {
            NavigationStack {
                Form { TextField("Nombre", text: $name) }
                    .navigationTitle("Nueva colección")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showCreate = false } }
                        ToolbarItem(placement: .confirmationAction) { Button("Crear") { Task { if await model.create(name: name.trimmingCharacters(in: .whitespacesAndNewlines), accessToken: session.accessToken) { name = ""; showCreate = false } } }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2) }
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
        .navigationTitle(collection.name)
    }
}

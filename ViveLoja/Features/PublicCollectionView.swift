import SwiftUI

@MainActor
@Observable
final class PublicCollectionViewModel {
    private(set) var collection: MobilePublicCollection?
    private(set) var isLoading = false
    private(set) var isSaving = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(slug: String, token: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            collection = try await api.get("/collections/\(slug)", bearer: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar la colección."
        }
    }

    /// Saving someone else's collection is a favorite like any other, so it
    /// lands in Guardados next to venues and events.
    func toggleSaved(token: String?) async {
        guard let collection, let token else { return }
        isSaving = true
        defer { isSaving = false }

        let request = FavoriteRequest(kind: "collection", itemId: collection.id)
        do {
            if collection.isSaved {
                let _: EmptyResponse = try await api.delete("/me/favorites", body: request, bearer: token)
            } else {
                let _: FavoriteRecord = try await api.post("/me/favorites", body: request, bearer: token)
            }
            VLFeedback.success()
            await load(slug: collection.slug, token: token)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo guardar la colección."
            VLFeedback.error()
        }
    }
}

/// A public collection opened from a shared link. Read-only: editing happens in
/// "Mis colecciones", which is where the owner already is.
struct PublicCollectionView: View {
    let slug: String

    @Environment(SessionStore.self) private var session
    @State private var model = PublicCollectionViewModel()

    var body: some View {
        List {
            if let collection = model.collection {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Text(collection.icon ?? "✨").font(.largeTitle)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(collection.name).font(.title3.weight(.bold))
                                if let author = collection.author?.name {
                                    Text("por \(author)").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let description = collection.description, !description.isEmpty {
                            Text(description).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text("\(collection.itemCount) guardados · \(collection.saveCount) personas la siguen")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                if !collection.isMine, session.user != nil {
                    Section {
                        Button {
                            Task { await model.toggleSaved(token: session.accessToken) }
                        } label: {
                            Label(
                                collection.isSaved ? "Guardada" : "Guardar colección",
                                systemImage: collection.isSaved ? "heart.fill" : "heart"
                            )
                        }
                        .disabled(model.isSaving)
                    }
                }

                Section("Contenido") {
                    ForEach(collection.items) { entry in
                        PublicCollectionRow(entry: entry)
                    }
                }
            } else if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(model.collection?.name ?? "Colección")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let collection = model.collection {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: AppEnvironment.current.shareURL(for: .collection, slug: collection.slug)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Compartir colección")
                }
            }
        }
        .overlay {
            if model.isLoading && model.collection == nil { ProgressView("Cargando colección…") }
        }
        .task { await model.load(slug: slug, token: session.accessToken) }
    }
}

private struct PublicCollectionRow: View {
    let entry: MobilePublicCollectionItem

    var body: some View {
        if let item = entry.item {
            // Venues and events open their detail; routes open the itinerary.
            // Posts have no native reader, so they stay as plain rows.
            switch item.kind {
            case "route":
                NavigationLink {
                    RouteDetailView(slug: item.slug, placeholderTitle: item.title)
                } label: {
                    content(for: item)
                }
            case "venue", "event":
                NavigationLink {
                    DeepLinkDestinationView(
                        destination: item.kind == "venue" ? .venue(slug: item.slug) : .event(slug: item.slug)
                    )
                } label: {
                    content(for: item)
                }
            default:
                content(for: item)
            }
        }
    }

    private func content(for item: MobilePublicCollectionItem.Entry) -> some View {
        HStack(spacing: 12) {
            VLAsyncImage(url: item.image, height: 62)
                .frame(width: 82)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                if let note = entry.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.tertiary)
                }
            }
        }
    }
}

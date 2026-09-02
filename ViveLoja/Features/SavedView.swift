import SwiftUI
import Observation

@MainActor
@Observable
final class SavedViewModel {
    var favorites: [FavoriteRecord] = []
    var isLoading = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { favorites = []; errorMessage = nil; return }
        isLoading = true
        defer { isLoading = false }
        do {
            favorites = try await APIClient.shared.get("/me/favorites", bearer: accessToken)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus guardados."
        }
    }

    func remove(_ favorite: FavoriteRecord, accessToken: String?) async {
        guard let accessToken else { return }
        do {
            let _: EmptyResponse = try await APIClient.shared.delete("/me/favorites", body: FavoriteRequest(kind: favorite.kind, itemId: favorite.itemId), bearer: accessToken)
            favorites.removeAll { $0.id == favorite.id }
            VLFeedback.success()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo quitar el guardado."
            VLFeedback.error()
        }
    }
}

struct SavedView: View {
    @Environment(SavedStore.self) private var saved
    @Environment(SessionStore.self) private var session
    @State private var model = SavedViewModel()
    private let fixtures = HomeViewModel.fixtures

    var body: some View {
        NavigationStack {
            Group {
                if session.user != nil {
                    remoteContent
                } else {
                    localContent
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Guardados")
            .toolbarTitleDisplayMode(.inlineLarge)
            .task(id: session.user?.id) {
                if let token = session.accessToken {
                    await saved.sync(accessToken: token)
                    await model.load(accessToken: token)
                } else {
                    await model.load(accessToken: nil)
                }
            }
            .refreshable {
                guard let token = session.accessToken else { return }
                await model.load(accessToken: token)
                await saved.sync(accessToken: token)
            }
        }
    }

    @ViewBuilder
    private var localContent: some View {
        let items = fixtures.filter { saved.contains($0) }
        if items.isEmpty {
            ContentUnavailableView("Aún no hay guardados", systemImage: "heart", description: Text("Guarda locales y eventos para encontrarlos aquí."))
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(items) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            VLItemCard(item: item)
                        }
                        .buttonStyle(.plain)
                        .contextMenu { Button("Quitar de guardados", systemImage: "heart.slash") { saved.toggle(item, accessToken: session.accessToken) } }
                    }
                }.padding(16)
            }
        }
    }

    @ViewBuilder
    private var remoteContent: some View {
        if model.isLoading && model.favorites.isEmpty {
            ProgressView("Cargando guardados…")
        } else if let error = model.errorMessage, model.favorites.isEmpty {
            ContentUnavailableView("Sin conexión", systemImage: "wifi.exclamationmark", description: Text(error))
        } else if model.favorites.isEmpty {
            ContentUnavailableView("Aún no hay guardados", systemImage: "heart", description: Text("Guarda locales y eventos para encontrarlos aquí."))
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(model.favorites, id: \.id) { favorite in
                        remoteRow(favorite)
                    }
                }
                .padding(16)
            }
        }
    }

    @ViewBuilder
    private func remoteRow(_ favorite: FavoriteRecord) -> some View {
        if let item = favorite.item, let exploreItem = item.exploreItem {
            NavigationLink(destination: ItemDetailView(item: exploreItem)) {
                VLItemCard(item: exploreItem)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("saved-\(favorite.kind)-\(favorite.itemId)")
            .contextMenu { removeButton(favorite) }
        } else if let item = favorite.item {
            HStack(spacing: 12) {
                VLAsyncImage(url: item.image, height: 68)
                    .frame(width: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title).font(.headline).lineLimit(2)
                    Text(item.subtitle ?? item.kind.capitalized).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer()
            }
            .padding(12)
            .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("saved-\(favorite.kind)-\(favorite.itemId)")
            .contextMenu { removeButton(favorite) }
        } else {
            Label("Contenido guardado", systemImage: "bookmark.fill")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityLabel("Contenido guardado, \(favorite.kind)")
                .contextMenu { removeButton(favorite) }
        }
    }

    private func removeButton(_ favorite: FavoriteRecord) -> some View {
        Button("Quitar de guardados", role: .destructive) {
            Task { await model.remove(favorite, accessToken: session.accessToken) }
        }
    }
}

private extension FavoriteSummary {
    var exploreItem: ExploreItem? {
        switch kind {
        case "venue":
            return .venue(ExploreVenue(id: id, name: title, slug: slug, description: description, image: image, location: subtitle, address: address, lat: lat, lng: lng, featured: false, phone: nil, website: nil, priceRange: nil, avgRating: nil, reviewCount: 0, verified: false, categories: []))
        case "event":
            return .event(ExploreEvent(id: id, title: title, slug: slug, description: description, image: image, startDate: startDate ?? .now, endDate: nil, location: subtitle, address: address, lat: lat, lng: lng, featured: false, price: nil, avgRating: nil, reviewCount: 0, categories: []))
        default:
            return nil
        }
    }
}

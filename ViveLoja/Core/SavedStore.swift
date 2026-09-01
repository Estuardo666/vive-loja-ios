import Foundation
import Observation

@MainActor
@Observable
final class SavedStore {
    private let defaults: UserDefaults
    private let api = APIClient.shared
    private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ids = Set(defaults.stringArray(forKey: "savedItemIDs") ?? [])
    }

    func contains(_ item: ExploreItem) -> Bool { ids.contains(item.id) }

    func toggle(_ item: ExploreItem, accessToken: String? = nil) {
        let wasSaved = ids.contains(item.id)
        if wasSaved { ids.remove(item.id) } else { ids.insert(item.id) }
        defaults.set(Array(ids), forKey: "savedItemIDs")

        guard let accessToken else { return }
        let request = FavoriteRequest(kind: item.kind, itemId: item.rawID)
        Task {
            if wasSaved {
                let _: EmptyResponse? = try? await api.delete("/me/favorites", body: request, bearer: accessToken)
            } else {
                let _: FavoriteRecord? = try? await api.post("/me/favorites", body: request, bearer: accessToken)
            }
        }
    }

    func sync(accessToken: String) async {
        guard let remote: [FavoriteRecord] = try? await api.get("/me/favorites", bearer: accessToken) else { return }
        ids.formUnion(remote.map { "\($0.kind)-\($0.itemId)" })
        defaults.set(Array(ids), forKey: "savedItemIDs")
    }
}

private extension ExploreItem {
    var rawID: String {
        switch self { case .venue(let value): return value.id; case .event(let value): return value.id }
    }

    var kind: String {
        switch self { case .venue: return "venue"; case .event: return "event" }
    }
}

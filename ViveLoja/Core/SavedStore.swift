import Observation

@MainActor
@Observable
final class SavedStore {
    private let defaults: UserDefaults
    private(set) var ids: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.ids = Set(defaults.stringArray(forKey: "savedItemIDs") ?? [])
    }

    func contains(_ item: ExploreItem) -> Bool { ids.contains(item.id) }

    func toggle(_ item: ExploreItem) {
        if ids.contains(item.id) { ids.remove(item.id) } else { ids.insert(item.id) }
        defaults.set(Array(ids), forKey: "savedItemIDs")
    }
}

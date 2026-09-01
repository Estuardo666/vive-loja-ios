import XCTest
@testable import ViveLoja

@MainActor
final class ViveLojaTests: XCTestCase {
    func testExploreVenueAndEventHaveStableIdentifiers() {
        let category = Category(id: "c", name: "Cafés", slug: "cafes", icon: "☕", color: nil)
        let venue = ExploreVenue(id: "v", name: "Café", slug: "cafe", description: "", image: nil, location: "Centro", address: nil, lat: -4, lng: -79, featured: false, phone: nil, website: nil, priceRange: nil, avgRating: nil, reviewCount: 0, verified: false, categories: [category])
        let event = ExploreEvent(id: "e", title: "Evento", slug: "evento", description: "", image: nil, startDate: Date(), endDate: nil, location: "Loja", address: nil, lat: -4, lng: -79, featured: false, price: nil, avgRating: nil, reviewCount: 0, categories: [])
        XCTAssertEqual(ExploreItem.venue(venue).id, "venue-v")
        XCTAssertEqual(ExploreItem.event(event).id, "event-e")
    }

    func testSavedStorePersistsToggle() {
        let suiteName = "ViveLojaTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SavedStore(defaults: defaults)
        let item = HomeViewModel.fixtures[0]

        XCTAssertFalse(store.contains(item))
        store.toggle(item)
        XCTAssertTrue(store.contains(item))

        let restored = SavedStore(defaults: defaults)
        XCTAssertTrue(restored.contains(item))
        restored.toggle(item)
        XCTAssertFalse(restored.contains(item))
    }

    func testProductionAPIUsesCanonicalMobilePath() {
        XCTAssertEqual(AppEnvironment.production.baseURL.absoluteString, "https://viveloja.com/api/mobile/v1")
    }
}

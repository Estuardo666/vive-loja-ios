import XCTest
@testable import ViveLoja

final class ViveLojaTests: XCTestCase {
    func testExploreVenueAndEventHaveStableIdentifiers() {
        let category = Category(id: "c", name: "Cafés", slug: "cafes", icon: "☕", color: nil)
        let venue = ExploreVenue(id: "v", name: "Café", slug: "cafe", description: "", image: nil, location: "Centro", address: nil, lat: -4, lng: -79, featured: false, phone: nil, website: nil, priceRange: nil, avgRating: nil, reviewCount: 0, verified: false, categories: [category])
        let event = ExploreEvent(id: "e", title: "Evento", slug: "evento", description: "", image: nil, startDate: Date(), endDate: nil, location: "Loja", address: nil, lat: -4, lng: -79, featured: false, price: nil, avgRating: nil, reviewCount: 0, categories: [])
        XCTAssertEqual(ExploreItem.venue(venue).id, "venue-v")
        XCTAssertEqual(ExploreItem.event(event).id, "event-e")
    }
}

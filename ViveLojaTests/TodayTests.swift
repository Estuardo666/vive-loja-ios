import XCTest
@testable import ViveLoja

@MainActor
final class TodayTests: XCTestCase {
    func testEmptyTodayContractDecodes() throws {
        let data = Data("""
        {"date":"2026-09-04","timeZone":"America/Guayaquil","generatedAt":"2026-09-04T12:00:00Z",
         "events":[],"openVenues":[],"routes":[],"collections":[]}
        """.utf8)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(TodayPayload.self, from: data)
        XCTAssertEqual(payload.date, "2026-09-04")
        XCTAssertTrue(payload.collections.isEmpty)
    }

    func testEventTimeAlwaysUsesLojaTime() {
        let date = ISO8601DateFormatter().date(from: "2026-09-04T06:00:00Z")!
        XCTAssertEqual(TodayInLojaView.eventTime(date), "01:00")
    }

    func testNewCardNavigatesToExistingCollection() {
        XCTAssertEqual(DeepLinkRouter.destination(kind: "collection", slug: "cafes"), .collection(slug: "cafes"))
    }

    func testAgendaAndEventUpdateContracts() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let event = try decoder.decode(AgendaEvent.self, from: Data("""
        {"id":"e1","title":"Concierto","slug":"concierto","image":null,
        "startDate":"2026-09-04T23:00:00Z","location":"Teatro","price":null}
        """.utf8))
        XCTAssertNil(event.price)
        XCTAssertEqual(TodayInLojaView.eventTime(event.startDate), "18:00")
        let notice = try decoder.decode(EventUpdateNotice.self, from: Data("""
        {"id":"n1","title":"Evento cancelado","body":"Concierto cancelado",
        "slug":"concierto","createdAt":"2026-09-04T23:00:00Z"}
        """.utf8))
        XCTAssertEqual(notice.slug, event.slug)
    }

    func testTouristRouteRequestIncludesStopsAndNumericDuration() throws {
        let stop = CreateRouteStopRequest(venueId: nil, title: "Teatro", notes: "Visita la fachada", duration: nil, lat: -3.99, lng: -79.2)
        let request = CreateRouteRequest(title: "Centro cultural", description: "Recorrido por el centro", content: nil, image: nil,
            duration: "120 min", difficulty: nil, type: "cultural", stops: [stop], estimatedMinutes: 120)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        XCTAssertEqual(object["estimatedMinutes"] as? Int, 120)
        let stops = try XCTUnwrap(object["stops"] as? [[String: Any]])
        XCTAssertEqual(stops.first?["lat"] as? Double, -3.99)
    }
}

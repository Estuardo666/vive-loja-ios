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
}

import XCTest
@testable import ViveLoja

final class HomeCardTests: XCTestCase {
    func testDescriptionDecodesWithoutBreakingOlderSnapshots() throws {
        let decoder = JSONDecoder.viveLoja
        let newCard = try decoder.decode(HomeItem.self, from: Data("""
        {"kind":"venue","id":"v1","slug":"cafe-loja","title":"Café Loja","subtitle":"Centro","description":"Café de altura","address":"Calle Bolívar","deeplink":"/locales/cafe-loja"}
        """.utf8))
        let oldCard = try decoder.decode(HomeItem.self, from: Data("""
        {"kind":"event","id":"e1","slug":"concierto","title":"Concierto","deeplink":"/eventos/concierto"}
        """.utf8))
        XCTAssertEqual(newCard.description, "Café de altura")
        XCTAssertEqual(newCard.address, "Calle Bolívar")
        XCTAssertNil(oldCard.description)
        XCTAssertNil(oldCard.address)
    }

    func testEventCardUsesServerDate() throws {
        let card = try JSONDecoder.viveLoja.decode(HomeItem.self, from: Data("""
        {"kind":"event","id":"e1","slug":"concierto","title":"Concierto","startDate":"2026-10-20T19:00:00.000Z","deeplink":"/eventos/concierto"}
        """.utf8))
        XCTAssertNotNil(card.startDate)
    }
}

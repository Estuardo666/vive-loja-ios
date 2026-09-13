import XCTest
@testable import ViveLoja

@MainActor
final class TicketDeepLinkTests: XCTestCase {
    func testCheckoutResultUniversalLinkOpensNativePaymentResult() {
        let router = DeepLinkRouter()
        let token = String(repeating: "T", count: 43)
        router.handle(URL(string: "https://viveloja.com/checkout/result?token=\(token)&clientTransactionId=vl_123&status=paid")!)

        XCTAssertEqual(router.pendingCheckoutResult?.token, token)
        XCTAssertEqual(router.pendingCheckoutResult?.clientTransactionId, "vl_123")
        XCTAssertEqual(router.pendingCheckoutResult?.status, "paid")
        XCTAssertNil(router.pendingDestination)
    }

    func testCheckoutResultUniversalLinkRejectsMissingBearerToken() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://viveloja.com/checkout/result?status=paid")!)
        XCTAssertNil(router.pendingCheckoutResult)
    }

    func testCheckoutResultCustomSchemeProvidesSafariFallback() {
        let router = DeepLinkRouter()
        let token = String(repeating: "F", count: 43)
        router.handle(URL(string: "viveloja://checkout/result?token=\(token)&clientTransactionId=vl_456&status=failed")!)

        XCTAssertEqual(router.pendingCheckoutResult?.token, token)
        XCTAssertEqual(router.pendingCheckoutResult?.clientTransactionId, "vl_456")
        XCTAssertEqual(router.pendingCheckoutResult?.status, "failed")
    }

    func testTicketCheckoutURLUsesFirstPartyBrowserRoute() {
        let token = String(repeating: "P", count: 43)
        let url = AppEnvironment.production.ticketCheckoutURL(token: token)
        XCTAssertEqual(url.host, "viveloja.com")
        XCTAssertEqual(url.path, "/checkout/payphone")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first?.value, token)
    }
}

import XCTest
@testable import ViveLoja

private struct APIClientTestPayload: Decodable, Sendable, Equatable {
    let value: String
}

private struct VenueCacheTestPayload: Decodable, Sendable, Equatable {
    let value: String
    let googleRating: Double?
}

fileprivate final class APIClientURLProtocol: URLProtocol, @unchecked Sendable {
    fileprivate struct RequestRecord: Sendable {
        let reloadsIgnoringLocalCache: Bool
        let cacheControl: String?
        let authorization: String?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var records: [RequestRecord] = []

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        records.removeAll()
    }

    fileprivate static var requestRecords: [RequestRecord] {
        lock.lock(); defer { lock.unlock() }
        return records
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lock.lock()
        Self.records.append(RequestRecord(
            reloadsIgnoringLocalCache: request.cachePolicy == .reloadIgnoringLocalCacheData,
            cacheControl: request.value(forHTTPHeaderField: "Cache-Control"),
            authorization: request.value(forHTTPHeaderField: "Authorization")
        ))
        Self.lock.unlock()

        let responseBody: Data
        if url.path.contains("/venues/") {
            responseBody = Data(#"{"data":{"value":"ok","googleRating":4.8,"googleReviewCount":32}}"#.utf8)
        } else {
            responseBody = Data(#"{"data":{"value":"ok"}}"#.utf8)
        }
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: responseBody)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
    private func makeClient() -> APIClient {
        APIClientURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [APIClientURLProtocol.self]
        return APIClient(environment: .development, session: URLSession(configuration: configuration))
    }

    func testPublicGetsShareInFlightRequestAndReuseMemoryCache() async throws {
        let client = makeClient()

        async let first: APIClientTestPayload = client.get("/public/events")
        async let second: APIClientTestPayload = client.get("/public/events")
        let results = try await [first, second]
        let third: APIClientTestPayload = try await client.get("/public/events")

        XCTAssertEqual(results, [APIClientTestPayload(value: "ok"), APIClientTestPayload(value: "ok")])
        XCTAssertEqual(third.value, "ok")
        XCTAssertEqual(APIClientURLProtocol.requestRecords.count, 1)
    }

    func testBearerGetsNeverEntersPublicCacheOrURLCache() async throws {
        let client = makeClient()

        let first: APIClientTestPayload = try await client.get("/me/profile", bearer: "secret")
        let second: APIClientTestPayload = try await client.get("/me/profile", bearer: "secret")

        XCTAssertEqual(first, second)
        let records = APIClientURLProtocol.requestRecords
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records.allSatisfy { $0.reloadsIgnoringLocalCache })
        XCTAssertTrue(records.allSatisfy { $0.cacheControl == "no-store" })
        XCTAssertTrue(records.allSatisfy { $0.authorization == "Bearer secret" })
    }

    func testVenueDetailsCacheOnlyFirstPartyFields() async throws {
        let client = makeClient()

        let first: VenueCacheTestPayload = try await client.get("/venues/cafe-central")
        let second: VenueCacheTestPayload = try await client.get("/venues/cafe-central")

        XCTAssertEqual(first.googleRating, 4.8)
        XCTAssertNil(second.googleRating, "Cached venue details must not retain Google-derived fields")
        XCTAssertEqual(APIClientURLProtocol.requestRecords.count, 1)
    }
}

import XCTest
@testable import ViveLoja

private final class PhotoURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var count = 0

    static func resetCount() {
        lock.lock(); defer { lock.unlock() }
        count = 0
    }

    static var requestCount: Int {
        lock.lock(); defer { lock.unlock() }
        return count
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock(); Self.count += 1; Self.lock.unlock()
        guard let url = request.url else { return }
        // Both metadata and image requests must bypass persistent caches.
        guard request.cachePolicy == .reloadIgnoringLocalCacheData,
              request.value(forHTTPHeaderField: "Cache-Control") == "no-store",
              request.value(forHTTPHeaderField: "X-Goog-Api-Key") == nil else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let body: Data
        let status: Int
        if url.path == "/photo" {
            body = Data("image-bytes".utf8)
            status = 200
        } else if url.path.contains("/missing/") {
            body = Data(#"{"photo":null}"#.utf8)
            status = 200
        } else if url.path.contains("/limited/") {
            body = Data(#"{"photo":null}"#.utf8)
            status = 429
        } else if url.path == "/api/venues/local/google-photo", url.query == "size=large" {
            body = Data(#"{"photo":{"photoUri":"https://photos.example/photo","googleMapsUri":"https://maps.google.com/photo","authors":[{"displayName":"Autora","uri":"https://maps.google.com/author"}]}}"#.utf8)
            status = 200
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        guard let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil) else { return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class GoogleVenuePhotoTests: XCTestCase {
    private func makeClient() -> GoogleVenuePhotoClient {
        PhotoURLProtocol.resetCount()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PhotoURLProtocol.self]
        return GoogleVenuePhotoClient(session: URLSession(configuration: configuration))
    }

    func testLoadsDirectImageAndPreservesAttributionWithoutCredentialsOrCache() async throws {
        let result = try await makeClient().load(slug: "local", large: true)
        XCTAssertEqual(result?.0.authors.first?.displayName, "Autora")
        XCTAssertEqual(result?.0.googleMapsUri.absoluteString, "https://maps.google.com/photo")
        XCTAssertEqual(result?.1, Data("image-bytes".utf8))
    }

    func testMissingPhotoAndInvalidSlugReturnNoImage() async throws {
        let client = makeClient()
        let missing = try await client.load(slug: "missing", large: false)
        let invalid = try await client.load(slug: "../private", large: false)
        XCTAssertNil(missing)
        XCTAssertNil(invalid)
    }

    /// A venue revisited inside the session must not hit the network again:
    /// each load costs one Places lookup plus one photo download upstream.
    func testRepeatedLoadIsServedFromSessionCache() async throws {
        let client = makeClient()
        let first = try await client.load(slug: "local", large: true)
        let afterFirst = PhotoURLProtocol.requestCount
        let second = try await client.load(slug: "local", large: true)

        XCTAssertEqual(afterFirst, 2, "Expected one metadata and one image request")
        XCTAssertEqual(PhotoURLProtocol.requestCount, afterFirst, "Second load must not touch the network")
        XCTAssertEqual(first?.1, second?.1)
        XCTAssertEqual(second?.0.googleMapsUri, first?.0.googleMapsUri)
    }

    /// Concurrent views of the same venue share one request rather than racing.
    func testConcurrentLoadsShareASingleRequest() async throws {
        let client = makeClient()
        async let first = client.load(slug: "local", large: true)
        async let second = client.load(slug: "local", large: true)
        let results = try await [first, second]

        XCTAssertEqual(PhotoURLProtocol.requestCount, 2, "Both callers must share one metadata and one image request")
        XCTAssertEqual(results[0]?.1, results[1]?.1)
    }

    /// Invalidation exists for images that arrive but fail to decode.
    func testInvalidateForcesAReload() async throws {
        let client = makeClient()
        _ = try await client.load(slug: "local", large: true)
        await client.invalidate(slug: "local", large: true)
        _ = try await client.load(slug: "local", large: true)

        XCTAssertEqual(PhotoURLProtocol.requestCount, 4, "Expected a fresh fetch after invalidation")
    }

    func testRateLimitDoesNotAttemptImageDownload() async {
        do {
            _ = try await makeClient().load(slug: "limited", large: false)
            XCTFail("Expected a rate limit failure")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }
}

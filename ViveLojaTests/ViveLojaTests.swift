import CoreLocation
import XCTest
@testable import ViveLoja

private final class StubAPIURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if url.path.hasSuffix("/offline") {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let status = url.path.hasSuffix("/error") ? 401 : 200
        let body = status == 200
            ? Data("{\"data\":{\"ok\":true}}".utf8)
            : Data("{\"error\":{\"code\":\"AUTH_REQUIRED\",\"message\":\"Sesión vencida\"}}".utf8)
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private struct StubPayload: Decodable, Sendable { let ok: Bool }

private final class SSEStubURLProtocol: URLProtocol, @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var attempts = 0

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        attempts = 0
    }

    static var attemptCount: Int {
        lock.lock(); defer { lock.unlock() }
        return attempts
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.attempts += 1
        let attempt = Self.attempts
        Self.lock.unlock()

        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if attempt == 1 {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            let body = Data("event: connected\ndata: {\"ignored\":true}\n\n".utf8)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
        }
    }

    override func stopLoading() {}
}

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

    func testDeepLinksResolveToPublicDetails() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://viveloja.com/locales/cafe-loja")!)
        XCTAssertEqual(router.destination, .venue(slug: "cafe-loja"))

        router.handle(URL(string: "viveloja://eventos/musica-en-vivo")!)
        XCTAssertEqual(router.destination, .event(slug: "musica-en-vivo"))
    }

    func testContentPayloadDefaultsMissingSectionsToEmptyCollections() throws {
        let payload = try JSONDecoder().decode(ContentPayload.self, from: Data("{}".utf8))
        XCTAssertTrue(payload.posts.isEmpty)
        XCTAssertTrue(payload.categories.isEmpty)
        XCTAssertTrue(payload.promotions.isEmpty)
        XCTAssertTrue(payload.routes.isEmpty)
        XCTAssertTrue(payload.collections.isEmpty)
    }

    func testGeoMathUsesMetersForProximityFilters() {
        let center = CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422)
        let nearby = CLLocationCoordinate2D(latitude: -3.99370, longitude: -79.20422)
        let distant = CLLocationCoordinate2D(latitude: -4.01000, longitude: -79.20422)

        XCTAssertLessThan(GeoMath.distanceMeters(from: center, to: nearby), 100)
        XCTAssertTrue(GeoMath.contains(nearby, in: 100, around: center))
        XCTAssertFalse(GeoMath.contains(distant, in: 1_000, around: center))
    }

    func testExploreFiltersCountAndReset() {
        let model = ExploreViewModel()
        XCTAssertEqual(model.activeFilterCount, 0)

        model.minRating = 4
        model.openNow = true
        model.services = ["Delivery"]
        model.eventDatePreset = "thisWeekend"
        XCTAssertEqual(model.activeFilterCount, 4)

        model.resetFilters()
        XCTAssertEqual(model.activeFilterCount, 0)
        XCTAssertNil(model.minRating)
        XCTAssertFalse(model.openNow)
        XCTAssertTrue(model.services.isEmpty)
        XCTAssertNil(model.eventDatePreset)
    }

    func testReviewAcceptsLegacyCommentField() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let review = try decoder.decode(MobileReview.self, from: Data("""
        {"id":"r1","rating":5,"comment":"Muy recomendado","createdAt":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(review.content, "Muy recomendado")
        XCTAssertEqual(review.rating, 5)
    }

    func testReviewPhotosDecodeAndDefault() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let withPhoto = try decoder.decode(MobileReview.self, from: Data("""
        {"id":"r2","rating":4,"content":"Bien","createdAt":"2026-01-01T00:00:00Z","photos":[{"id":"p1","url":"https://example.com/p.jpg","order":0}]}
        """.utf8))
        XCTAssertEqual(withPhoto.photos.count, 1)
        let withoutPhoto = try decoder.decode(MobileReview.self, from: Data("""
        {"id":"r3","rating":3,"content":"Ok","createdAt":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertTrue(withoutPhoto.photos.isEmpty)
    }

    func testDetailModelsTolerateMissingQuestions() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = Data("""
        {"id":"v1","name":"Café","slug":"cafe","description":"Desc","image":null,"location":"Loja","address":null,"lat":null,"lng":null,"featured":false,"phone":null,"website":null,"priceRange":null,"avgRating":null,"reviewCount":0,"verified":false,"categories":[],"media":[],"services":[],"reviews":[]}
        """.utf8)
        let detail = try decoder.decode(VenueDetail.self, from: data)
        XCTAssertNil(detail.questions)
    }

    func testAPIClientMapsSuccessServerErrorAndOfflineTransport() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAPIURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: configuration))

        let payload: StubPayload = try await client.get("health")
        XCTAssertTrue(payload.ok)

        do {
            let _: StubPayload = try await client.get("error")
            XCTFail("Expected an authentication error")
        } catch let error as APIError {
            guard case .server(let code, _, let status) = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
            XCTAssertEqual(code, "AUTH_REQUIRED")
            XCTAssertEqual(status, 401)
        }

        do {
            let _: StubPayload = try await client.get("offline")
            XCTFail("Expected an offline transport error")
        } catch let error as APIError {
            guard case .transport = error else {
                return XCTFail("Unexpected API error: \(error)")
            }
        }
    }

    func testConversationStreamRetriesAfterDisconnectAndCanStop() async throws {
        SSEStubURLProtocol.reset()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SSEStubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let model = ConversationViewModel(
            streamSession: session,
            streamURL: URL(string: "https://example.test/messages/stream")!
        )

        model.startStream(accessToken: "test-token")
        for _ in 0..<30 where SSEStubURLProtocol.attemptCount < 2 {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertGreaterThanOrEqual(SSEStubURLProtocol.attemptCount, 2)
        XCTAssertEqual(model.streamStatus, .reconnecting)

        model.stopStream()
        XCTAssertEqual(model.streamStatus, .idle)
    }
}

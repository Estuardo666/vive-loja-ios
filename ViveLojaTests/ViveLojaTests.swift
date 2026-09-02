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
        if url.path.hasSuffix("/slow") {
            Thread.sleep(forTimeInterval: 0.15)
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

private final class MemoryKeychainStore: SecureKeyValueStore, @unchecked Sendable {
    private var values: [String: String] = [:]

    func save(_ value: String, for key: String) throws { values[key] = value }
    func read(_ key: String) -> String? { values[key] }
    func delete(_ key: String) { values.removeValue(forKey: key) }
}

private final class RefreshStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) private static var statusCode = 200

    static func setStatusCode(_ value: Int) { statusCode = value }

    override class func canInit(with request: URLRequest) -> Bool { request.url?.path.hasSuffix("/auth/refresh") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let status = Self.statusCode
        let body = status == 200
            ? Data("""
            {"data":{"accessToken":"new-access","refreshToken":"new-refresh","expiresIn":3600,"user":{"id":"u1","name":"Demo","email":"demo@viveloja.test","role":"USER"}}}
            """.utf8)
            : Data("{\"error\":{\"code\":\"AUTH_REQUIRED\",\"message\":\"Sesión vencida\"}}".utf8)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

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

    func testUIFixturesUseStableEventDate() {
        guard case .event(let event) = HomeViewModel.fixtures[1] else {
            return XCTFail("La fixture esperada debe ser un evento")
        }
        XCTAssertEqual(event.startDate, Date(timeIntervalSince1970: 1_800_000_000))
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

    func testFavoriteRecordDecodesEnrichedSummaryAndLegacyShape() throws {
        let enriched = Data("""
        {"id":"fav-1","kind":"venue","itemId":"venue-1","createdAt":"2026-09-01T12:00:00Z","item":{"kind":"venue","id":"venue-1","title":"Café Loja","slug":"cafe-loja","description":"Café de altura","image":"https://example.com/cafe.jpg","subtitle":"Centro histórico","address":"Calle Bolívar","lat":-4.0079,"lng":-79.2045,"startDate":null}}
        """.utf8)
        let legacy = Data(#"{"id":"fav-2","kind":"event","itemId":"event-2","createdAt":null}"#.utf8)
        let decoder = JSONDecoder.viveLoja

        let record = try decoder.decode(FavoriteRecord.self, from: enriched)
        XCTAssertEqual(record.item?.title, "Café Loja")
        XCTAssertEqual(record.item?.image?.absoluteString, "https://example.com/cafe.jpg")
        XCTAssertNil(try decoder.decode(FavoriteRecord.self, from: legacy).item)
    }

    /// Prisma serialises every timestamp through `Date.prototype.toJSON`, so
    /// the wire format always carries milliseconds. The suite used to build its
    /// own `.iso8601` decoder and feed it fixtures without them, which is how a
    /// profile that no device could actually parse still passed every test.
    func testProfileAndBadgesDecodeTheMillisecondTimestampsTheAPIActuallySends() throws {
        let decoder = JSONDecoder.viveLoja
        let profile = try decoder.decode(MobileProfile.self, from: Data("""
        {"id":"u1","name":"Estuardo","email":"e@viveloja.com","role":"USER","image":null,"reputationScore":12,"reviewerLevel":2,"totalReviews":3,"totalCheckIns":4,"totalPhotos":5,"onboardingCompletedAt":"2026-02-23T06:14:16.251Z","onboardingSkippedAt":null}
        """.utf8))
        XCTAssertNotNil(profile.onboardingCompletedAt)
        XCTAssertNil(profile.onboardingSkippedAt)

        let badge = try decoder.decode(MobileBadge.self, from: Data("""
        {"id":"b1","badgeType":"FIRST_REVIEW","name":"Primera Reseña","description":"Escribiste tu primera reseña","icon":"✍️","earnedAt":"2026-02-23T06:14:17.172Z"}
        """.utf8))
        XCTAssertEqual(badge.id, "b1")

        // Without the fractional part too: the contract does not promise them.
        let plain = try decoder.decode(MobileBadge.self, from: Data("""
        {"id":"b2","badgeType":"EXPLORER","name":"Explorador","description":"Diez check-ins","icon":null,"earnedAt":"2026-02-23T06:14:17Z"}
        """.utf8))
        XCTAssertEqual(plain.id, "b2")
    }

    func testFollowingAndBadgeModelsDecodeMobileContracts() throws {
        let decoder = JSONDecoder.viveLoja
        let following = try decoder.decode(MobileFollowingRecord.self, from: Data("""
        {"id":"f1","venueId":"v1","createdAt":"2026-09-01T12:00:00Z","venue":{"id":"v1","name":"Café Loja","slug":"cafe-loja","image":null,"location":"Centro","address":null,"phone":"0991234567","lat":-4.0,"lng":-79.2}}
        """.utf8))
        XCTAssertEqual(following.venue.slug, "cafe-loja")
        XCTAssertEqual(following.venue.phone, "0991234567")

        let badge = try decoder.decode(MobileBadge.self, from: Data("""
        {"id":"b1","badgeType":"FIRST_REVIEW","name":"Primera Reseña","description":"Escribiste tu primera reseña","icon":"✍️","earnedAt":"2026-09-01T12:00:00Z"}
        """.utf8))
        XCTAssertEqual(badge.badgeType, "FIRST_REVIEW")
    }

    func testWatchEventAndRecommendationsModelsDecodeContracts() throws {
        let decoder = JSONDecoder.viveLoja
        let watchEvent = try decoder.decode(MobileWatchEvent.self, from: Data("""
        {"id":"w1","name":"Final","slug":"final","type":"SPORTS","description":"Partido","image":null,"matchDate":"2026-09-01T20:00:00Z","matchTime":"20:00","competition":"Liga","performers":[{"id":"p1","name":"Local","slug":"local","type":"TEAM","logo":null,"role":"HOME"}],"featured":true,"viewCount":4,"venueCount":2}
        """.utf8))
        XCTAssertEqual(watchEvent.performers.first?.role, "HOME")
        let recommendations = try decoder.decode(MobileRecommendations.self, from: Data("""
        {"interests":{"categories":[],"preferences":["Cultura"]},"followingVenues":[],"relatedEvents":[],"relatedVenues":[]}
        """.utf8))
        XCTAssertEqual(recommendations.interests.preferences, ["Cultura"])
    }

    /// Articles are read on the public site because the mobile API never
    /// returns a post's body, so the app has to derive that URL from the API
    /// base rather than hardcoding the production host.
    func testArticleURLIsDerivedFromTheAPIBase() {
        XCTAssertEqual(
            AppEnvironment.production.articleURL(slug: "ruta-ecologica-senderos-loja").absoluteString,
            "https://viveloja.com/blog/ruta-ecologica-senderos-loja"
        )
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

        router.handle(URL(string: "https://viveloja.com/partidos/final-loja")!)
        XCTAssertEqual(router.destination, .watchEvent(slug: "final-loja"))
    }

    func testContentPayloadDefaultsMissingSectionsToEmptyCollections() throws {
        let payload = try JSONDecoder().decode(ContentPayload.self, from: Data("{}".utf8))
        XCTAssertTrue(payload.posts.isEmpty)
        XCTAssertTrue(payload.categories.isEmpty)
        XCTAssertTrue(payload.promotions.isEmpty)
        XCTAssertTrue(payload.routes.isEmpty)
        XCTAssertTrue(payload.collections.isEmpty)
        XCTAssertTrue(payload.watchEvents.isEmpty)
    }

    func testHomePayloadKeepsEditorialSectionsBackwardCompatible() throws {
        let decoder = JSONDecoder.viveLoja
        let legacy = try decoder.decode(HomePayload.self, from: Data("""
        {"venues":[],"events":[],"categories":[],"pageInfo":null}
        """.utf8))
        XCTAssertNil(legacy.latestVenues)
        XCTAssertNil(legacy.posts)

        let enriched = try decoder.decode(HomePayload.self, from: Data("""
        {"venues":[],"events":[],"categories":[],"pageInfo":null,"featuredVenues":[],"featuredEvents":[],"latestVenues":[],"relatedEvents":[],"posts":[],"promotions":[]}
        """.utf8))
        XCTAssertEqual(enriched.latestVenues?.count, 0)
        XCTAssertEqual(enriched.posts?.count, 0)
        XCTAssertEqual(enriched.promotions?.count, 0)
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
        let decoder = JSONDecoder.viveLoja
        let review = try decoder.decode(MobileReview.self, from: Data("""
        {"id":"r1","rating":5,"comment":"Muy recomendado","createdAt":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(review.content, "Muy recomendado")
        XCTAssertEqual(review.rating, 5)
    }

    func testReviewPhotosDecodeAndDefault() throws {
        let decoder = JSONDecoder.viveLoja
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
        let decoder = JSONDecoder.viveLoja
        let data = Data("""
        {"id":"v1","name":"Café","slug":"cafe","description":"Desc","image":null,"location":"Loja","address":null,"lat":null,"lng":null,"featured":false,"phone":null,"website":null,"priceRange":null,"avgRating":null,"reviewCount":0,"verified":false,"categories":[],"media":[],"services":[],"reviews":[]}
        """.utf8)
        let detail = try decoder.decode(VenueDetail.self, from: data)
        XCTAssertNil(detail.questions)
    }

    func testVenueDetailDecodesHoursMenuProductsAndPromotions() throws {
        let decoder = JSONDecoder.viveLoja
        let detail = try decoder.decode(VenueDetail.self, from: Data("""
        {
          "id":"v1","name":"Café","slug":"cafe","description":"Desc","image":null,
          "location":"Loja","address":null,"lat":null,"lng":null,"featured":false,
          "phone":null,"website":null,"priceRange":null,"avgRating":4.5,"reviewCount":2,
          "verified":true,"categories":[],"media":[],"services":[],"operatingHours":null,
          "businessHours":[{"id":"h1","dayOfWeek":1,"openTime":"08:00","closeTime":"18:00","isClosed":false}],
          "menu":[{"id":"m1","name":"Desayunos","order":0,"items":[{"id":"i1","name":"Bolón","description":"Con café","price":3.5,"image":null,"order":0,"isAvailable":true,"isFeatured":true}]}],
          "products":[{"id":"p1","name":"Café lojano","description":null,"price":2,"image":null,"isAvailable":true,"isFeatured":false,"order":0}],
          "events":[{"id":"e1","title":"Cata","slug":"cata","startDate":"2026-05-01T18:00:00Z","location":"Café","address":null}],
          "promotions":[{"id":"promo1","title":"2x1","description":"Dos por uno","image":null,"discount":"50%","validFrom":"2026-04-01T00:00:00Z","validUntil":"2026-05-01T00:00:00Z","terms":null,"featured":true}],
          "reviews":[],"questions":[]
        }
        """.utf8))
        XCTAssertEqual(detail.businessHours?.count, 1)
        XCTAssertEqual(detail.menu?.first?.items.first?.name, "Bolón")
        XCTAssertEqual(detail.products?.first?.price, 2)
        XCTAssertEqual(detail.events?.first?.title, "Cata")
        XCTAssertEqual(detail.promotions?.first?.discount, "50%")
    }

    func testModerationDraftDTOsDecodeTheirOwnEndpointShapes() throws {
        let decoder = JSONDecoder.viveLoja
        let venue = try decoder.decode(MobileVenueDraft.self, from: Data("""
        {"id":"v1","name":"Café","slug":"cafe","description":"Un lugar","image":null,"location":"Centro","address":null,"status":"PENDING","createdAt":"2026-01-01T00:00:00Z"}
        """.utf8))
        XCTAssertEqual(venue.status, "PENDING")

        let post = try decoder.decode(MobilePostDraft.self, from: Data("""
        {"id":"p1","title":"Guía","slug":"guia","excerpt":null,"content":"Contenido","image":null,"status":"APPROVED","createdAt":"2026-01-02T00:00:00Z","category":{"id":"c1","name":"Cultura","slug":"cultura","icon":null,"color":null}}
        """.utf8))
        XCTAssertEqual(post.category?.slug, "cultura")

        let route = try decoder.decode(MobileRouteDraft.self, from: Data("""
        {"id":"r1","title":"Centro","slug":"centro","description":"Ruta","content":null,"image":null,"duration":null,"difficulty":null,"type":"cultural","status":"REJECTED","createdAt":"2026-01-03T00:00:00Z","stops":[]}
        """.utf8))
        XCTAssertEqual(route.status, "REJECTED")
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

    func testAPIClientHandlesSlowTransportWithoutLosingTheRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubAPIURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: configuration))
        let started = Date()

        let payload: StubPayload = try await client.get("slow")

        XCTAssertTrue(payload.ok)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(started), 0.1)
    }

    func testSessionStoreRefreshRotatesTokens() async throws {
        RefreshStubURLProtocol.setStatusCode(200)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshStubURLProtocol.self]
        let keychain = MemoryKeychainStore()
        try keychain.save("old-access", for: "accessToken")
        try keychain.save("old-refresh", for: "refreshToken")
        let client = APIClient(session: URLSession(configuration: configuration))
        let session = SessionStore(api: client, keychain: keychain)

        await session.restore()
        XCTAssertEqual(session.accessToken, "old-access")
        let refreshed = await session.refresh()
        XCTAssertTrue(refreshed)
        XCTAssertEqual(session.accessToken, "new-access")
        XCTAssertEqual(session.user?.email, "demo@viveloja.test")
    }

    func testSessionStoreClearsExpiredSessionAfterRefresh401() async throws {
        RefreshStubURLProtocol.setStatusCode(401)
        defer { RefreshStubURLProtocol.setStatusCode(200) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RefreshStubURLProtocol.self]
        let keychain = MemoryKeychainStore()
        try keychain.save("old-access", for: "accessToken")
        try keychain.save("old-refresh", for: "refreshToken")
        let client = APIClient(session: URLSession(configuration: configuration))
        let session = SessionStore(api: client, keychain: keychain)

        await session.restore()
        let refreshed = await session.refresh()

        XCTAssertFalse(refreshed)
        XCTAssertNil(session.accessToken)
        XCTAssertNil(session.user)
        XCTAssertEqual(session.errorMessage, "Sesión vencida")
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

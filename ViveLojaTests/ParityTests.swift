import CoreLocation
import XCTest
@testable import ViveLoja

/// Coverage for the cross-platform parity work: canonical share URLs and deep
/// links, push payload routing, notification preferences and multi-day
/// itineraries. Split out of ViveLojaTests, which had grown past the linter's
/// type body limit.
@MainActor
final class ParityTests: XCTestCase {
    func testDeepLinksResolveToPublicDetails() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://viveloja.com/locales/cafe-loja")!)
        XCTAssertEqual(router.pendingDestination, .venue(slug: "cafe-loja"))

        router.handle(URL(string: "viveloja://eventos/musica-en-vivo")!)
        XCTAssertEqual(router.pendingDestination, .event(slug: "musica-en-vivo"))

        router.handle(URL(string: "https://viveloja.com/partidos/final-loja")!)
        XCTAssertEqual(router.pendingDestination, .watchEvent(slug: "final-loja"))

        router.handle(URL(string: "https://viveloja.com/rutas/centro-historico")!)
        XCTAssertEqual(router.pendingDestination, .route(slug: "centro-historico"))

        router.handle(URL(string: "https://www.viveloja.com/colecciones/cafeterias")!)
        XCTAssertEqual(router.pendingDestination, .collection(slug: "cafeterias"))

        // A path the site does not publish must not be claimed.
        router.pendingDestination = nil
        router.handle(URL(string: "https://viveloja.com/admin/usuarios")!)
        XCTAssertNil(router.pendingDestination)
    }

    /// Every shareable kind has to survive the round trip through the canonical
    /// URL, otherwise the app claims a Universal Link it cannot resolve and the
    /// tap silently falls back to Safari.
    func testCanonicalShareURLsRoundTripThroughTheRouter() {
        let router = DeepLinkRouter()
        for kind in ShareableKind.allCases {
            let url = AppEnvironment.production.shareURL(for: kind, slug: "prueba")
            XCTAssertEqual(url.absoluteString, "https://viveloja.com/\(kind.pathSegment)/prueba")

            router.pendingDestination = nil
            router.handle(url)
            XCTAssertEqual(router.pendingDestination, DeepLinkRouter.destination(for: kind, slug: "prueba"))
        }
    }

    /// Deep links land on a tab's navigation stack; a second tap on the same
    /// link must not stack a duplicate screen.
    func testDeepLinkPushesOntoItsTabStackWithoutDuplicating() {
        let router = DeepLinkRouter()
        router.handle(URL(string: "https://viveloja.com/locales/cafe-loja")!)
        XCTAssertEqual(router.consumePendingDestination(), .explore)
        XCTAssertEqual(router.explorePath, [.venue(slug: "cafe-loja")])

        router.handle(URL(string: "https://viveloja.com/locales/cafe-loja")!)
        _ = router.consumePendingDestination()
        XCTAssertEqual(router.explorePath, [.venue(slug: "cafe-loja")])

        router.handle(URL(string: "https://viveloja.com/colecciones/cafeterias")!)
        XCTAssertEqual(router.consumePendingDestination(), .saved)
        XCTAssertEqual(router.savedPath, [.collection(slug: "cafeterias")])
        XCTAssertNil(router.pendingDestination)
    }

    /// The settings screen round-trips the whole row through PATCH, so the
    /// encoded body has to carry every flag the backend validates.
    func testNotificationPreferencesRoundTripThroughTheAPIShape() throws {
        let json = Data("""
        {"enabled":true,"hoursAhead":24,"pushEnabled":false,"emailEnabled":true,"eventReminders":true,"newFollowedVenuePost":false,"reviewReply":true,"claimUpdates":true,"messageReceived":false,"moderationUpdates":true}
        """.utf8)

        let decoded = try JSONDecoder.viveLoja.decode(NotificationPreferences.self, from: json)
        XCTAssertEqual(decoded.hoursAhead, 24)
        XCTAssertFalse(decoded.pushEnabled)
        XCTAssertFalse(decoded.messageReceived)

        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        XCTAssertEqual(encoded?.keys.count, 10)
        XCTAssertEqual(encoded?["newFollowedVenuePost"] as? Bool, false)
    }

    /// A push payload has to reach the same screen a shared link does.
    func testPushPayloadDeepLinkRoutesLikeAUniversalLink() {
        let router = DeepLinkRouter()
        let service = PushService()
        service.attach(session: SessionStore(), router: router)

        service.handle(userInfo: ["deepLink": "https://viveloja.com/eventos/feria-de-loja"])
        XCTAssertEqual(router.pendingDestination, .event(slug: "feria-de-loja"))

        router.pendingDestination = nil
        service.handle(userInfo: ["aps": ["alert": "hola"]])
        XCTAssertNil(router.pendingDestination)
    }

    /// Routes created before itineraries existed carry no `day`, and the app
    /// must keep rendering them as a single day rather than failing to decode.
    func testRouteStopDefaultsToDayOneWhenTheServerOmitsIt() throws {
        let json = Data("""
        {"id":"s1","title":"Catedral","notes":null,"duration":"30 min","order":0,"venue":{"id":"v1","name":"Catedral","slug":"catedral"}}
        """.utf8)

        let stop = try JSONDecoder.viveLoja.decode(MobileRouteStop.self, from: json)
        XCTAssertEqual(stop.day, 1)
        XCTAssertNil(stop.coordinate?.lat)
    }

    func testRouteStopFallsBackToItsVenueCoordinate() throws {
        let json = Data("""
        {"id":"s1","title":"Parada","day":2,"order":0,"lat":null,"lng":null,"venue":{"id":"v1","name":"Café","slug":"cafe","lat":-4.0,"lng":-79.2}}
        """.utf8)

        let stop = try JSONDecoder.viveLoja.decode(MobileRouteStop.self, from: json)
        XCTAssertEqual(stop.day, 2)
        XCTAssertEqual(stop.coordinate?.lat, -4.0)
        XCTAssertEqual(stop.coordinate?.lng, -79.2)
    }

    /// The day picker reads `itinerary`; when an older server omits it the
    /// detail regroups the flat list instead of showing nothing.
    func testRouteDetailRebuildsTheItineraryWhenTheServerOmitsIt() throws {
        let json = Data("""
        {"id":"r1","title":"Dos días","slug":"dos-dias","description":"Ruta","content":null,"image":null,"duration":null,"difficulty":null,"type":"cultural","featured":false,"days":2,"distanceMeters":null,"estimatedMinutes":null,"startLat":null,"startLng":null,"favoriteCount":0,"author":null,"itinerary":[],"stops":[{"id":"a","title":"Uno","day":1,"order":0},{"id":"b","title":"Dos","day":2,"order":0}]}
        """.utf8)

        let detail = try JSONDecoder.viveLoja.decode(MobileRouteDetail.self, from: json)
        let itinerary = detail.resolvedItinerary
        XCTAssertEqual(itinerary.map(\.day), [1, 2])
        XCTAssertEqual(itinerary[1].stops.first?.id, "b")
    }

    func testRouteSummaryAcceptsBothStopCountAndInlineStops() throws {
        let listed = try JSONDecoder.viveLoja.decode(MobileRoute.self, from: Data("""
        {"id":"r1","title":"Ruta","slug":"ruta","description":"d","type":"cultural","days":3,"stopCount":7}
        """.utf8))
        XCTAssertEqual(listed.stopCount, 7)
        XCTAssertEqual(listed.days, 3)
        XCTAssertTrue(listed.stops.isEmpty)

        let embedded = try JSONDecoder.viveLoja.decode(MobileRoute.self, from: Data("""
        {"id":"r2","title":"Ruta","slug":"ruta-2","description":"d","type":"cultural","stops":[{"id":"a","title":"Uno","order":0}]}
        """.utf8))
        // No `days` on the payload means a single-day route.
        XCTAssertEqual(embedded.days, 1)
        XCTAssertEqual(embedded.stopCount, 1)
    }
}

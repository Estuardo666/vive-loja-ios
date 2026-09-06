import Foundation

/// Server-driven home screen.
///
/// The home used to be a fixed stack of sections compiled into the app, which
/// meant a new carousel needed a release. Now `/home` returns an ordered list of
/// `HomeSection`s and the view renders whatever it gets, so titles, filters,
/// order and visibility are editable from the admin panel.

/// One card, whatever kind of content produced it.
struct HomeItem: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case venue, event, post, route, collection, promotion, category
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }
    }

    let kind: Kind
    private let rawId: String
    let slug: String
    let title: String
    let subtitle: String?
    let imageUrl: URL?
    /// Wording is decided by the backend so campaigns do not need a release.
    let badge: String?
    let priceLabel: String?
    let rating: Double?
    let reviewCount: Int?
    let venueName: String?
    let dateLabel: String?
    let lat: Double?
    let lng: Double?
    let color: String?
    let icon: String?
    let deeplink: String?

    /// Ids repeat across kinds, and a section may mix them.
    var id: String { "\(kind.rawValue):\(rawId)" }
    var itemId: String { rawId }

    enum CodingKeys: String, CodingKey {
        case kind
        case rawId = "id"
        case slug, title, subtitle, imageUrl, badge, priceLabel, rating, reviewCount
        case venueName, dateLabel, lat, lng, color, icon, deeplink
    }

    /// Where a tap leads, when the app knows how to show it.
    var destination: DeepLinkRouter.Destination? {
        switch kind {
        case .venue, .promotion: return .venue(slug: slug)
        case .event: return .event(slug: slug)
        case .post: return .post(slug: slug)
        case .route: return .route(slug: slug)
        case .collection: return .collection(slug: slug)
        case .category, .unknown: return nil
        }
    }
}

struct HomeSection: Codable, Identifiable, Hashable, Sendable {
    /// Only the layouts the app knows how to draw. An unrecognised value decodes
    /// to `unknown` and the section is skipped, so a backend that ships a new
    /// layout never breaks an installed build.
    enum Layout: String, Codable, Sendable {
        case hero, chips, carousel, ranked, grid, list
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Layout(rawValue: raw) ?? .unknown
        }
    }

    /// Same tolerance as `Layout`: unknown types are ignored rather than fatal.
    enum Kind: String, Codable, Sendable {
        case hero, todayInLoja, categoryChips, venueList, openNow, eventList, ranked
        case collection, promotions, posts, routes, manual
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }
    }

    let id: String
    let type: Kind
    let title: String
    let subtitle: String?
    let actionLabel: String?
    let layout: Layout
    let deeplink: String?
    /// Hero copy, when the section is a hero.
    let body: String?
    let items: [HomeItem]

    /// A section the app cannot draw, or an empty carousel, is not rendered.
    var isRenderable: Bool {
        guard layout != .unknown, type != .unknown else { return false }
        if type == .hero || type == .todayInLoja { return true }
        return !items.isEmpty
    }
}

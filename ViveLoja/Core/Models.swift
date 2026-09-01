import Foundation

struct MobileUser: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let email: String
    let role: String
}

struct MobileTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: MobileUser
}

struct LoginRequest: Codable, Sendable { let email: String; let password: String }
struct RegisterRequest: Codable, Sendable { let name: String; let email: String; let password: String }
struct RefreshRequest: Codable, Sendable { let refreshToken: String }
struct AppleLoginRequest: Codable, Sendable {
    let identityToken: String
    let nonce: String?
    let name: String?
}

struct Category: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let icon: String?
    let color: String?
}

struct ExploreVenue: Codable, Identifiable, Hashable, Sendable {
    let id: String; let name: String; let slug: String; let description: String?
    let image: URL?; let location: String?; let address: String?; let lat: Double?; let lng: Double?
    let featured: Bool; let phone: String?; let website: URL?; let priceRange: String?
    let avgRating: Double?; let reviewCount: Int; let verified: Bool; let categories: [Category]
}

struct ExploreEvent: Codable, Identifiable, Hashable, Sendable {
    let id: String; let title: String; let slug: String; let description: String?
    let image: URL?; let startDate: Date; let endDate: Date?; let location: String?; let address: String?
    let lat: Double?; let lng: Double?; let featured: Bool; let price: Double?
    let avgRating: Double?; let reviewCount: Int; let categories: [Category]
}

enum ExploreItem: Identifiable, Hashable, Sendable {
    case venue(ExploreVenue)
    case event(ExploreEvent)

    var id: String {
        switch self { case .venue(let value): return "venue-\(value.id)"; case .event(let value): return "event-\(value.id)" }
    }
    var title: String {
        switch self { case .venue(let value): return value.name; case .event(let value): return value.title }
    }
    var coordinate: (lat: Double, lng: Double)? {
        switch self {
        case .venue(let value) where value.lat != nil && value.lng != nil: return (value.lat!, value.lng!)
        case .event(let value) where value.lat != nil && value.lng != nil: return (value.lat!, value.lng!)
        default: return nil
        }
    }
}

struct ExplorePageInfo: Codable, Sendable { let hasMoreVenues: Bool; let hasMoreEvents: Bool; let nextVenueSkip: Int; let nextEventSkip: Int }
struct ExplorePayload: Codable, Sendable { let venues: [ExploreVenue]; let events: [ExploreEvent]; let pageInfo: ExplorePageInfo? }
struct HomePayload: Codable, Sendable { let venues: [ExploreVenue]; let events: [ExploreEvent]; let categories: [Category]; let pageInfo: ExplorePageInfo? }

struct MobileTag: Codable, Hashable, Sendable { let id: String; let name: String; let slug: String }
struct MobilePost: Codable, Identifiable, Hashable, Sendable {
    let id: String; let title: String; let slug: String; let excerpt: String?; let image: URL?
    let status: String; let featured: Bool; let publishedAt: Date?; let createdAt: Date
    let category: Category?; let author: MobileAuthor?; let tags: [MobileTag]
}
struct MobileAuthor: Codable, Hashable, Sendable { let id: String; let name: String? }
struct MobileVenueSummary: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let location: String?
    let address: String?
}
struct MobilePromotion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String
    let image: URL?
    let discount: String?
    let validFrom: Date
    let validUntil: Date
    let terms: String?
    let featured: Bool
    let venue: MobileVenueSummary
}
struct MobileRouteStop: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let duration: String?
    let order: Int
    let venue: MobileVenueShort?
}
struct MobileVenueShort: Codable, Hashable, Sendable { let id: String; let name: String; let slug: String }
struct MobileRoute: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let image: URL?
    let duration: String?
    let difficulty: String?
    let type: String
    let featured: Bool
    let stops: [MobileRouteStop]
}
struct MobileCollection: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let icon: String?
    let itemCount: Int
    let user: MobileAuthor?
}
struct ContentPayload: Codable, Sendable {
    let posts: [MobilePost]
    let categories: [Category]
    let promotions: [MobilePromotion]
    let routes: [MobileRoute]
    let collections: [MobileCollection]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posts = try container.decodeIfPresent([MobilePost].self, forKey: .posts) ?? []
        categories = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        promotions = try container.decodeIfPresent([MobilePromotion].self, forKey: .promotions) ?? []
        routes = try container.decodeIfPresent([MobileRoute].self, forKey: .routes) ?? []
        collections = try container.decodeIfPresent([MobileCollection].self, forKey: .collections) ?? []
    }

    private enum CodingKeys: String, CodingKey { case posts, categories, promotions, routes, collections }
}
struct FavoriteRequest: Codable, Sendable { let kind: String; let itemId: String }
struct FavoriteRecord: Codable, Sendable { let id: String; let kind: String; let itemId: String; let createdAt: Date? }

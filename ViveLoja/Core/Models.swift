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

import Foundation

struct MobileUser: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let email: String
    let role: String
}

struct MobileProfile: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let email: String
    let role: String
    let image: URL?
    let reputationScore: Int
    let reviewerLevel: Int
    let totalReviews: Int
    let totalCheckIns: Int
    let totalPhotos: Int
    let onboardingCompletedAt: Date?
    let onboardingSkippedAt: Date?
}

struct ProfileUpdateRequest: Codable, Sendable {
    let name: String?
    let image: URL?
}

struct MobileInterests: Decodable, Sendable {
    let categories: [Category]
    let preferences: [String]
}

struct MobileCollectionItem: Decodable, Identifiable, Sendable {
    let id: String
    let venueId: String?
    let eventId: String?
    let postId: String?
    let routeId: String?
    let note: String?
    let order: Int
    let createdAt: Date
    let venue: CollectionVenue?
    let event: CollectionEvent?
    let post: CollectionPost?
    let route: CollectionRoute?
}

struct CollectionVenue: Decodable, Sendable { let id: String; let name: String; let slug: String; let image: URL? }
struct CollectionEvent: Decodable, Sendable { let id: String; let title: String; let slug: String; let image: URL? }
struct CollectionPost: Decodable, Sendable { let id: String; let title: String; let slug: String; let image: URL? }
struct CollectionRoute: Decodable, Sendable { let id: String; let title: String; let slug: String; let image: URL? }

struct MobileOwnedCollection: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let icon: String?
    let isPublic: Bool
    let createdAt: Date
    let updatedAt: Date
    let items: [MobileCollectionItem]
}

struct CollectionRequest: Codable, Sendable {
    let name: String
    let description: String?
    let icon: String?
    let isPublic: Bool?
}

struct CollectionItemRequest: Codable, Sendable {
    let kind: String
    let itemId: String
    let note: String?
    let order: Int?
}

struct CollectionItemKey: Codable, Sendable {
    let kind: String
    let itemId: String
}

struct MobileCheckIn: Decodable, Identifiable, Sendable {
    let id: String
    let venueId: String
    let lat: Double
    let lng: Double
    let note: String?
    let photoUrl: URL?
    let createdAt: Date
    let venue: CollectionVenue
}

struct CheckInRequest: Codable, Sendable {
    let venueId: String
    let lat: Double
    let lng: Double
    let note: String?
    let photoUrl: URL?
}

struct InterestsRequest: Codable, Sendable {
    let categoryIds: [String]
    let preferences: [String]
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

struct MobileMedia: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let alt: String?
    let type: String
    let order: Int
}

struct MobileService: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
}

struct MobileReviewUser: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let image: URL?
}

struct MobileReviewPhoto: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let url: URL
    let order: Int
}

struct MobileReview: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let rating: Int
    let title: String?
    let content: String?
    let status: String?
    let createdAt: Date
    let user: MobileReviewUser?
    let photos: [MobileReviewPhoto]

    private enum CodingKeys: String, CodingKey { case id, rating, title, content, comment, status, createdAt, user, photos }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        rating = try container.decode(Int.self, forKey: .rating)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        if let value = try container.decodeIfPresent(String.self, forKey: .content) {
            content = value
        } else {
            content = try container.decodeIfPresent(String.self, forKey: .comment)
        }
        status = try container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        user = try container.decodeIfPresent(MobileReviewUser.self, forKey: .user)
        photos = try container.decodeIfPresent([MobileReviewPhoto].self, forKey: .photos) ?? []
    }
}

struct MobileQuestion: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let content: String
    let answer: String?
    let answerBy: String?
    let answeredAt: Date?
    let status: String
    let createdAt: Date
    let user: MobileReviewUser?
}

struct VenueDetail: Decodable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String
    let image: URL?
    let location: String?
    let address: String?
    let lat: Double?
    let lng: Double?
    let featured: Bool
    let phone: String?
    let website: URL?
    let priceRange: String?
    let avgRating: Double?
    let reviewCount: Int
    let verified: Bool
    let categories: [Category]
    let media: [MobileMedia]
    let services: [MobileService]
    let reviews: [MobileReview]
    let questions: [MobileQuestion]?
}

struct EventDetail: Decodable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let image: URL?
    let startDate: Date
    let endDate: Date?
    let location: String?
    let address: String?
    let lat: Double?
    let lng: Double?
    let featured: Bool
    let price: Double?
    let avgRating: Double?
    let reviewCount: Int
    let categories: [Category]
    let media: [MobileMedia]
    let reviews: [MobileReview]
    let venue: MobileVenueShort?
    let questions: [MobileQuestion]?
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

struct MobileEventShort: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
}

struct MobileReservation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let venueId: String?
    let eventId: String?
    let date: Date
    let time: String
    let partySize: Int
    let status: String
    let notes: String?
    let cancelReason: String?
    let createdAt: Date
    let updatedAt: Date
    let venue: MobileVenueShort?
    let event: MobileEventShort?
}

struct ReservationRequest: Codable, Sendable {
    let venueId: String?
    let eventId: String?
    let date: String
    let time: String
    let partySize: Int
    let notes: String?
}

struct MobileParticipant: Codable, Hashable, Sendable {
    let id: String
    let name: String?
    let image: URL?
}

struct MobileMessagePreview: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let venueId: String
    let senderId: String
    let receiverId: String
    let content: String?
    let images: [String]
    let isRead: Bool
    let createdAt: Date
}

struct MobileConversation: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let venue: MobileVenueShort
    let participant: MobileParticipant
    let lastMessage: MobileMessagePreview?
    let unreadCount: Int
}

struct MessageRequest: Codable, Sendable {
    let venueId: String
    let receiverId: String
    let content: String
}

struct MessageReportRequest: Codable, Sendable {
    let messageId: String
    let reason: String
}

struct MessageReportResponse: Decodable, Sendable {
    let reported: Bool
}

struct ReviewRequest: Codable, Sendable {
    let venueId: String?
    let eventId: String?
    let rating: Int
    let title: String?
    let content: String?
    let photos: [URL]?
}

struct QuestionRequest: Codable, Sendable {
    let venueId: String?
    let eventId: String?
    let content: String
}

struct CancelReservationRequest: Codable, Sendable {
    let status: String
    let cancelReason: String?
}

struct MobileUpload: Decodable, Sendable {
    let key: String
    let url: URL
    let contentType: String
    let size: Int
}

struct CreateEventRequest: Codable, Sendable {
    let title: String
    let description: String
    let startDate: String
    let endDate: String?
    let location: String
    let address: String?
    let lat: Double?
    let lng: Double?
    let price: Double?
    let image: URL?
    let venueId: String?
}

struct CreateVenueRequest: Codable, Sendable {
    let name: String; let description: String; let location: String; let address: String?
    let phone: String?; let email: String?; let website: String?; let lat: Double?; let lng: Double?
    let priceRange: String?; let image: URL?; let categoryIds: [String]?
}

struct CreatePostRequest: Codable, Sendable {
    let title: String; let excerpt: String?; let content: String; let image: URL?; let categoryId: String
}

struct CreateRouteStopRequest: Codable, Sendable {
    let venueId: String?; let title: String; let notes: String?; let duration: String?
}

struct CreateRouteRequest: Codable, Sendable {
    let title: String; let description: String; let content: String?; let image: URL?
    let duration: String?; let difficulty: String?; let type: String; let stops: [CreateRouteStopRequest]?
}

struct ModeratedDraft: Decodable, Sendable { let id: String; let status: String }

struct CreatedEvent: Codable, Sendable {
    let id: String
    let title: String
    let slug: String
    let status: String
}

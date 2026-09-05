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

struct MobileBadge: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let badgeType: String
    let name: String
    let description: String
    let icon: String?
    let earnedAt: Date
}

struct MobileFollowingVenue: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let image: URL?
    let location: String?
    let address: String?
    let phone: String?
    let lat: Double?
    let lng: Double?
}

struct MobileFollowingRecord: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let venueId: String
    let createdAt: Date
    let venue: MobileFollowingVenue
}

struct FollowingRequest: Codable, Sendable {
    let venueId: String
}

struct PasswordChangeRequest: Codable, Sendable {
    let currentPassword: String
    let newPassword: String
    let confirmPassword: String
}

struct MobileWatchPerformer: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let type: String
    let logo: URL?
    let role: String?
}

struct MobileWatchEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let type: String
    let description: String?
    let image: URL?
    let matchDate: Date
    let matchTime: String?
    let competition: String?
    let performers: [MobileWatchPerformer]
    let featured: Bool
    let viewCount: Int
    let venueCount: Int?
}

struct MobileWatchVenueSummary: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let image: URL?
    let phone: String?
    let address: String?
    let location: String?
    let lat: Double?
    let lng: Double?
    let avgRating: Double?
    let reviewCount: Int
    let priceRange: String?
}

struct MobileWatchVenue: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let flyerUrl: URL?
    let promotion: String?
    let hasBigScreen: Bool
    let hasFreeEntry: Bool
    let venue: MobileWatchVenueSummary
}

struct MobileWatchEventDetail: Codable, Sendable {
    let id: String
    let name: String
    let slug: String
    let type: String
    let description: String?
    let image: URL?
    let matchDate: Date
    let matchTime: String?
    let competition: String?
    let performers: [MobileWatchPerformer]
    let featured: Bool
    let viewCount: Int
    let venues: [MobileWatchVenue]
}

struct MobileRecommendations: Decodable, Sendable {
    let interests: MobileInterests
    let followingVenues: [MobileFollowingRecord]
    let relatedEvents: [ExploreEvent]
    let relatedVenues: [ExploreVenue]
}

struct ViewRequest: Codable, Sendable {
    let kind: String
    let itemId: String
    /// Which surface the view came from. The web and the PWA send their own
    /// values, so "popular now" can be broken down by platform later.
    let source: String

    init(kind: String, itemId: String, source: String = "ios") {
        self.kind = kind
        self.itemId = itemId
        self.source = source
    }
}

struct ViewResponse: Decodable, Sendable {
    let recorded: Bool
    let kind: String
    let itemId: String
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
/// Logout also drops the APNs token server-side, so a signed-out phone stops
/// receiving the previous account's notifications immediately.
struct LogoutRequest: Codable, Sendable {
    let refreshToken: String
    let deviceToken: String?
}
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

/// Open/closed state resolved on the server in Loja time (UTC-5), so the app never
/// recomputes it from raw hours and never disagrees with the "abierto ahora" filter.
/// Absent on payloads from a server that predates it.
struct OpenState: Codable, Hashable, Sendable {
    let isOpen: Bool
    let closesAt: String?
    let opensAt: String?

    var label: String {
        if isOpen { return closesAt.map { "Abierto · cierra \($0)" } ?? "Abierto" }
        return opensAt.map { "Cerrado · abre \($0)" } ?? "Cerrado"
    }

    /// Longer wording for the detail screen, where there is room for the whole
    /// sentence and the state is the headline rather than a card footnote.
    var detailLabel: String {
        if isOpen { return closesAt.map { "Abierto ahora · Cierra a las \($0)" } ?? "Abierto ahora" }
        return opensAt.map { "Cerrado · Abre a las \($0)" } ?? "Cerrado ahora"
    }
}

struct ExploreVenue: Codable, Identifiable, Hashable, Sendable {
    let id: String; let name: String; let slug: String; let description: String?
    let image: URL?; let location: String?; let address: String?; let lat: Double?; let lng: Double?
    let featured: Bool; let phone: String?; let website: URL?; let priceRange: String?
    let avgRating: Double?; let reviewCount: Int; let verified: Bool; let categories: [Category]
    let openState: OpenState?
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

struct MobileOperatingHours: Codable, Sendable {
    let id: String
    let mon: String?
    let tue: String?
    let wed: String?
    let thu: String?
    let fri: String?
    let sat: String?
    let sun: String?
    let notes: String?
}

struct MobileBusinessHours: Codable, Identifiable, Sendable {
    let id: String
    let dayOfWeek: Int
    let openTime: String
    let closeTime: String
    let isClosed: Bool
}

struct MobileMenuItem: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let price: Double?
    let image: URL?
    let order: Int
    let isAvailable: Bool
    let isFeatured: Bool
}

struct MobileMenuCategory: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let order: Int
    let items: [MobileMenuItem]
}

struct MobileProduct: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let price: Double?
    let image: URL?
    let isAvailable: Bool
    let isFeatured: Bool
    let order: Int
}

struct MobileVenuePromotion: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let image: URL?
    let discount: String?
    let validFrom: Date
    let validUntil: Date
    let terms: String?
    let featured: Bool
}

struct MobileVenueEvent: Codable, Identifiable, Sendable {
    let id: String
    let title: String
    let slug: String
    let startDate: Date
    let location: String
    let address: String?
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
    /// Reply written by the business owner, from the app or the web dashboard.
    let ownerReply: String?
    let ownerReplyAt: Date?
    let user: MobileReviewUser?
    let photos: [MobileReviewPhoto]

    private enum CodingKeys: String, CodingKey {
        case id, rating, title, content, comment, status, createdAt, ownerReply, ownerReplyAt, user, photos
    }

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
        ownerReply = try container.decodeIfPresent(String.self, forKey: .ownerReply)
        ownerReplyAt = try container.decodeIfPresent(Date.self, forKey: .ownerReplyAt)
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

/// Badge derived on the server from Google's rating and review count
/// ("Excelente en Google", "Popular en Google"), so the app and the web page
/// never disagree about the threshold.
struct GoogleBadge: Decodable, Hashable, Sendable, Identifiable {
    let type: String
    let label: String
    let icon: String

    var id: String { type }
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
    /// Google's rating for the place. Dropped by the server once its cached
    /// Places row goes stale, so `nil` means "no Google rating to show", never
    /// "zero stars". Showing it obliges us to link `googleMapsUrl`.
    let googleRating: Double?
    let googleReviewCount: Int?
    let googleBadges: [GoogleBadge]?
    let googleMapsUrl: URL?
    let verified: Bool
    /// Ownership flags. Absent on payloads from a server that predates claims,
    /// where nobody owns anything from the app's point of view.
    let claimed: Bool?
    let isOwnedByMe: Bool?
    let canReclaim: Bool?
    let categories: [Category]
    let media: [MobileMedia]
    let services: [MobileService]
    let operatingHours: MobileOperatingHours?
    let businessHours: [MobileBusinessHours]?
    let openState: OpenState?
    let menu: [MobileMenuCategory]?
    let products: [MobileProduct]?
    let events: [MobileVenueEvent]?
    let promotions: [MobileVenuePromotion]?
    let reviews: [MobileReview]
    let questions: [MobileQuestion]?
}

struct EventDetail: Decodable, Sendable {
    let status: String?
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
struct HomePayload: Codable, Sendable {
    let venues: [ExploreVenue]
    let events: [ExploreEvent]
    let categories: [Category]
    let pageInfo: ExplorePageInfo?
    // Optional fields keep older backend deployments and cached responses compatible.
    let featuredVenues: [ExploreVenue]?
    let featuredEvents: [ExploreEvent]?
    let latestVenues: [ExploreVenue]?
    let relatedEvents: [ExploreEvent]?
    /// Ranked by the shared view log across app, web and PWA. Absent on older
    /// deployments, in which case the section simply does not render.
    let popularNow: [ExploreVenue]?
    let posts: [MobilePost]?
    let promotions: [MobilePromotion]?
    /// Server-driven composition: the ordered sections the admin configured.
    /// Absent on older deployments, in which case the view falls back to the
    /// fixed sections built from the keys above.
    let sections: [HomeSection]?
}

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
    let watchEvents: [MobileWatchEvent]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        posts = try container.decodeIfPresent([MobilePost].self, forKey: .posts) ?? []
        categories = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
        promotions = try container.decodeIfPresent([MobilePromotion].self, forKey: .promotions) ?? []
        routes = try container.decodeIfPresent([MobileRoute].self, forKey: .routes) ?? []
        collections = try container.decodeIfPresent([MobileCollection].self, forKey: .collections) ?? []
        watchEvents = try container.decodeIfPresent([MobileWatchEvent].self, forKey: .watchEvents) ?? []
    }

    private enum CodingKeys: String, CodingKey { case posts, categories, promotions, routes, collections, watchEvents }
}
struct FavoriteRequest: Codable, Sendable { let kind: String; let itemId: String }
struct FavoriteSummary: Codable, Hashable, Sendable {
    let kind: String
    let id: String
    let title: String
    let slug: String
    let description: String?
    let image: URL?
    let subtitle: String?
    let address: String?
    let lat: Double?
    let lng: Double?
    let startDate: Date?
}

struct FavoriteRecord: Codable, Sendable {
    let id: String
    let kind: String
    let itemId: String
    let createdAt: Date?
    let item: FavoriteSummary?
}

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

struct MessageBlockRequest: Codable, Sendable {
    let venueId: String
    let userId: String
    let reason: String?
}

struct MessageBlockResponse: Decodable, Sendable {
    let blocked: Bool
    let removed: Bool?
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
    let lat: Double?
    let lng: Double?
    let venueId: String?
    let title: String
    let notes: String?
    let duration: String?
    /// 1-based. Omitted means day 1, which is how single-day routes behaved
    /// before itineraries existed.
    let day: Int?
    /// "HH:mm".
    let startTime: String?

    init(venueId: String?, title: String, notes: String?, duration: String?, day: Int? = nil, startTime: String? = nil, lat: Double? = nil, lng: Double? = nil) {
        self.lat = lat
        self.lng = lng
        self.venueId = venueId
        self.title = title
        self.notes = notes
        self.duration = duration
        self.day = day
        self.startTime = startTime
    }
}

struct CreateRouteRequest: Codable, Sendable {
    let estimatedMinutes: Int?
    let title: String
    let description: String
    let content: String?
    let image: URL?
    let duration: String?
    let difficulty: String?
    let type: String
    let days: Int?
    let stops: [CreateRouteStopRequest]?

    init(title: String, description: String, content: String?, image: URL?, duration: String?, difficulty: String?, type: String, days: Int? = nil, stops: [CreateRouteStopRequest]? = nil, estimatedMinutes: Int? = nil) {
        self.estimatedMinutes = estimatedMinutes
        self.title = title
        self.description = description
        self.content = content
        self.image = image
        self.duration = duration
        self.difficulty = difficulty
        self.type = type
        self.days = days
        self.stops = stops
    }
}

struct ModeratedDraft: Decodable, Sendable { let id: String; let status: String }

// The moderation list endpoints intentionally expose smaller DTOs than their
// public detail counterparts. Keeping them separate prevents a missing public
// field (for example `featured` or `publishedAt`) from breaking decoding.
struct MobileVenueDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String
    let image: URL?
    let location: String
    let address: String?
    let status: String
    let createdAt: Date
}

struct MobileEventDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let image: URL?
    let startDate: Date
    let endDate: Date?
    let location: String
    let address: String?
    let status: String
    let createdAt: Date
    let venue: MobileVenueShort?
}

struct MobilePostDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let excerpt: String?
    let content: String
    let image: URL?
    let status: String
    let createdAt: Date
    let category: Category?
}

struct MobileRouteStopDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let venueId: String?
    let day: Int
    let order: Int
    let title: String
    let notes: String?
    let duration: String?
    let startTime: String?

    enum CodingKeys: String, CodingKey {
        case id, venueId, day, order, title, notes, duration, startTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        venueId = try container.decodeIfPresent(String.self, forKey: .venueId)
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
    }
}

struct MobileRouteDraft: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let content: String?
    let image: URL?
    let duration: String?
    let difficulty: String?
    let type: String
    let status: String
    let createdAt: Date
    let days: Int?
    let stops: [MobileRouteStopDraft]
}

struct CreatedEvent: Codable, Sendable {
    let id: String
    let title: String
    let slug: String
    let status: String
}

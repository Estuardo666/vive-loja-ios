import Foundation

// Push registration, business claims, owner insights and public collections.
// Split out of Models.swift, which had grown past the linter's file length limit.


// MARK: - Push notifications

struct DeviceRegistrationRequest: Codable, Sendable {
    let token: String
    let platform: String
    let environment: String
    let locale: String
    let appVersion: String?
}

struct DeviceRegistrationResponse: Codable, Sendable {
    let id: String
    let platform: String
    let environment: String
}

struct DeviceRevocationRequest: Codable, Sendable {
    let token: String
}

/// Mirrors `/me/notification-preferences`. The web settings screen edits the
/// same row, so a change on either surface applies to both.
struct NotificationPreferences: Codable, Sendable, Equatable {
    var enabled: Bool
    var hoursAhead: Int
    var pushEnabled: Bool
    var emailEnabled: Bool
    var eventReminders: Bool
    var newFollowedVenuePost: Bool
    var reviewReply: Bool
    var claimUpdates: Bool
    var messageReceived: Bool
    var moderationUpdates: Bool

    static let defaults = NotificationPreferences(
        enabled: true,
        hoursAhead: 48,
        pushEnabled: true,
        emailEnabled: true,
        eventReminders: true,
        newFollowedVenuePost: true,
        reviewReply: true,
        claimUpdates: true,
        messageReceived: true,
        moderationUpdates: true
    )
}

// MARK: - Business claims and owner tools

struct MobilePlanCapabilities: Codable, Sendable, Hashable {
    let maxLocations: Int?
    let maxMembers: Int?
    let maxMediaPerVenue: Int?
    let googlePhotoEnabled: Bool
    let menuEnabled: Bool
    let servicesEnabled: Bool
    let monthlyEventsPerVenue: Int?
    let maxActivePromotionsPerVenue: Int?
    let analyticsRetentionDays: Int?
    let whatsappEnabled: Bool
    let messagingEnabled: Bool
    let reservationsEnabled: Bool
    let priorityModeration: Bool
    let includedBoostCredits: Int
}

struct MobilePlan: Codable, Identifiable, Sendable, Hashable {
    let slug: String
    let name: String
    let description: String?
    let versionId: String?
    let version: Int?
    let monthlyPrice: Double?
    let annualPrice: Double?
    let currency: String?
    let capabilities: MobilePlanCapabilities?
    var id: String { slug }
}

struct MobileAddonProduct: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let type: String
    let price: Double
    let currency: String
    let durationDays: Int?
    let requiresDelivery: Bool
}

struct MobileBillingSimulation: Codable, Sendable, Hashable {
    let enabled: Bool
    let label: String
    let chargedAmount: Double
    let renewsAutomatically: Bool
}

struct MobileBillingCatalog: Codable, Sendable {
    let plans: [MobilePlan]
    let addons: [MobileAddonProduct]
    let simulation: MobileBillingSimulation
}

struct MobileEffectivePlan: Codable, Sendable, Hashable {
    let slug: String
    let name: String
    let source: String
}

struct MobileBillingSubscription: Codable, Sendable, Hashable {
    let id: String
    let cycle: String
    let startsAt: Date
    let endsAt: Date
    let referencePrice: Double
    let mode: String
}

struct MobileBillingUsage: Codable, Sendable, Hashable {
    struct Limit: Codable, Sendable, Hashable { let used: Int; let limit: Int? }
    let locations: Limit
    let members: Limit
    let boostCredits: Limit?
}

struct MobileBusinessAccountSnapshot: Codable, Sendable {
    let account: AccountReference?
    let plan: MobilePlanSnapshot
    let subscription: MobileBillingSubscription?
    let usage: MobileBillingUsage
    let members: [MobileBusinessMember]
    let venues: [MobileBusinessVenue]
    let orders: [MobileBillingOrder]

    struct AccountReference: Codable, Sendable { let id: String; let name: String?; let role: String }
    struct MobilePlanSnapshot: Codable, Sendable { let slug: String; let name: String; let source: String; let capabilities: MobilePlanCapabilities; let entitlementsVersion: String }
    struct MobileBusinessMember: Codable, Sendable { let id: String; let role: String; let createdAt: Date; let user: MobileUser }
    struct MobileBusinessVenue: Codable, Sendable { let id: String; let name: String; let slug: String; let status: String; let media: MobileBillingUsage.Limit; let events: MobileBillingUsage.Limit; let promotions: MobileBillingUsage.Limit }
}

struct MobileBillingOrder: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let status: String
    let kind: String
    let mode: String
    let cycle: String?
    let referenceAmount: Double
    let chargedAmount: Double
    let currency: String
    let startsAt: Date?
    let endsAt: Date?
    let createdAt: Date
    let plan: MobileOrderPlan?
    let addon: MobileOrderAddon?
    struct MobileOrderPlan: Codable, Sendable, Hashable { let slug: String; let name: String; let version: Int }
    struct MobileOrderAddon: Codable, Sendable, Hashable { let slug: String; let name: String }
}

struct MobileCheckoutRequest: Codable, Sendable {
    let planSlug: String
    let cycle: String
    let idempotencyKey: String
    let device: String?
}

struct MobileAddBusinessMemberRequest: Codable, Sendable {
    let email: String
    let role: String
}

struct MobileClaimVenue: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let image: URL?
}

struct MobileClaim: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let status: String
    let verified: Bool
    let confidenceScore: Int
    let evidenceUrl: URL?
    let evidenceName: String?
    let createdAt: Date
    let venue: MobileClaimVenue?
    let planSelectionStatus: String?

    /// Spanish label for the raw status string the backend stores.
    var statusLabel: String {
        switch status {
        case "PENDING": return "Pendiente de verificación"
        case "VERIFIED": return "Verificado, en revisión"
        case "APPROVED": return "Aprobado"
        case "REJECTED": return "Rechazado"
        default: return status
        }
    }
}

struct CreateClaimRequest: Codable, Sendable {
    let venueId: String
    let claimerName: String
    let claimerEmail: String
    let claimerPhone: String?
    let claimerRole: String?
    let message: String?
}

struct CreateClaimResponse: Codable, Sendable {
    let claimId: String
    let venueSlug: String
    let confidenceScore: Int
}

struct VerifyClaimRequest: Codable, Sendable {
    let code: String
}

struct VerifyClaimResponse: Codable, Sendable {
    let verified: Bool
    let confidenceScore: Int
    let attemptsLeft: Int
}

struct ClaimEvidenceRequest: Codable, Sendable {
    let evidenceUrl: URL
    let evidenceName: String?
}

struct ReviewReplyRequest: Codable, Sendable {
    let reply: String
}

struct ReviewReplyResponse: Codable, Sendable {
    let id: String
    let ownerReply: String
    let ownerReplyAt: Date
}

/// `/me/venues/{slug}/insights` - the owner dashboard.
struct MobileVenueInsights: Codable, Sendable {
    struct VenueRef: Codable, Sendable {
        let id: String
        let name: String
        let slug: String
        let verified: Bool
    }

    struct DayPoint: Codable, Identifiable, Sendable {
        let date: String
        let views: Int

        var id: String { date }
    }

    let venue: VenueRef
    let lifetimeViews: Int
    let recentViews: Int
    let viewSeries: [DayPoint]
    let avgRating: Double?
    let reviewCount: Int
    let favorites: Int
    let pendingReviewReplies: Int
    let unansweredQuestions: Int
    let upcomingReservations: Int
    /// How far back `viewSeries` can reach; older rows are purged server-side.
    let retentionDays: Int
    let interactions: MobileInteractionMetrics?
}

struct MobileInteractionMetrics: Codable, Sendable {
    let days: Int
    let saves: Int
    let directions: Int
}

// MARK: - Public collections

struct MobilePublicCollectionItem: Codable, Identifiable, Hashable, Sendable {
    struct Entry: Codable, Hashable, Sendable {
        let kind: String
        let id: String
        let title: String
        let slug: String
        let image: URL?
        let subtitle: String?
        let lat: Double?
        let lng: Double?
        let startDate: Date?
    }

    let id: String
    let order: Int
    let note: String?
    let item: Entry?
}

struct MobilePublicCollection: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let icon: String?
    let itemCount: Int
    let saveCount: Int
    let isSaved: Bool
    let isMine: Bool
    let author: MobileAuthor?
    let items: [MobilePublicCollectionItem]
}

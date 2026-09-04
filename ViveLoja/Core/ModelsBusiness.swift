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

import Foundation

struct MobileTicketing: Codable, Sendable {
    let eventId: String
    let mode: String
    let externalUrl: URL?
    let externalProviderLabel: String?
    let currency: String?
    let feeIncidence: String?
    let feePercentBps: Int?
    let feeFixedCents: Int?
    let salesStartAt: Date?
    let salesEndAt: Date?
    let status: String?
    let ticketTypes: [MobileTicketType]?
    let seatMap: MobileSeatMap?
}

struct MobileTicketType: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let kind: String
    let priceCents: Int
    let capacity: Int?
    let available: Int?
    let minPerOrder: Int
    let maxPerOrder: Int
    let salesStartAt: Date?
    let salesEndAt: Date?
}

struct MobileSeatMap: Codable, Sendable {
    let id: String
    let version: Int
    let name: String?
    let seats: [MobileSeat]
}

struct MobileSeat: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let seatKey: String
    let section: String?
    let rowLabel: String?
    let seatNumber: String
    let coordinateX: Double?
    let coordinateY: Double?
    let status: String
    let ticketTypeId: String?

    enum CodingKeys: String, CodingKey {
        case id, seatKey, section, rowLabel, seatNumber, status, ticketTypeId
        case coordinateX = "x"
        case coordinateY = "y"
    }
}

struct MobileTicketSelection: Codable, Sendable {
    let ticketTypeId: String
    let quantity: Int
    let eventSeatIds: [String]?
}

struct MobileTicketHoldRequest: Codable, Sendable {
    let eventSlug: String
    let sessionKey: String
    let items: [MobileTicketSelection]
}

struct MobileTicketHold: Codable, Sendable {
    let id: String
    let token: String?
    let tokenLast4: String
    let expiresAt: Date
    let idempotent: Bool
}

struct MobileTicketCheckoutRequest: Codable, Sendable {
    let holdToken: String
    let buyerName: String
    let buyerEmail: String
    let buyerPhone: String
    let billingDocumentId: String?
}

struct MobileTicketCheckout: Codable, Sendable {
    let orderId: String
    let status: String
    let token: String
    let tokenLast4: String
    let expiresAt: Date
    let checkoutUrl: URL?
    let totalCents: Int
    let currency: String
    let clientTransactionId: String
}

struct MobileTicketOrder: Codable, Identifiable, Sendable {
    let id: String
    let status: String
    let totalCents: Int
    let currency: String
    let paidAt: Date?
    let event: MobileTicketEvent
    let tickets: [MobileTicket]
}

struct MobileTicketEvent: Codable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let startDate: Date
    let location: String
}

struct MobileTicket: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let code: String
    let qrData: URL
    let qrImageUrl: URL
    let seatLabel: String?
    let status: String
    let issuedAt: Date
    let ticketType: MobileTicketTypeSummary
}

struct MobileTicketTypeSummary: Codable, Hashable, Sendable {
    let name: String
    let kind: String
}

struct MobileTicketCheckInRequest: Codable, Sendable {
    let eventId: String
    let token: String
    let deviceId: String?
}

struct MobileTicketCheckIn: Codable, Sendable {
    let result: String
    let ticketId: String?
    let code: String?
    let seatLabel: String?
    let ticketType: String?
}

import Foundation

/// A private reference that lets the app recover a purchase without making an
/// account or searching by email. The token is a bearer secret, so only its
/// hash is ever stored by the API and the raw value stays in the iOS Keychain.
struct TicketAccessReference: Codable, Hashable, Sendable, Identifiable {
    enum Kind: String, Codable, Hashable, Sendable {
        case order
        case ticket
    }

    let kind: Kind
    let token: String

    var id: String { "\(kind.rawValue):\(token)" }

    var endpoint: String {
        let collection = kind == .order ? "orders" : "tickets"
        return "/ticketing/\(collection)/\(token)"
    }

    /// Accepts the private links sent by Vive Loja. A raw token is treated as
    /// an order token for users who copy it from the checkout result.
    static func parse(_ input: String) -> TicketAccessReference? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if let url = URL(string: value), let host = url.host?.lowercased() {
            guard host == "viveloja.com" || host == "www.viveloja.com" else { return nil }
            guard url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http" else { return nil }
            guard let token = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "token" })?.value,
                  isSafeToken(token) else { return nil }
            let path = url.path.lowercased()
            if path == "/tickets/scan" || path == "/tickets/scan/" {
                return TicketAccessReference(kind: .ticket, token: token)
            }
            if path == "/checkout/result" || path == "/checkout/result/" {
                return TicketAccessReference(kind: .order, token: token)
            }
            return nil
        }

        guard isSafeToken(value) else { return nil }
        return TicketAccessReference(kind: .order, token: value)
    }

    private static func isSafeToken(_ token: String) -> Bool {
        let length = token.utf8.count
        guard (20...160).contains(length) else { return false }
        return token.unicodeScalars.allSatisfy { scalar in
            switch scalar.value {
            case 48...57, 65...90, 97...122, 45, 95: return true
            default: return false
            }
        }
    }
}

struct TicketAccessStore: Sendable {
    private let keychain: any SecureKeyValueStore
    private let storageKey = "ticketing.access.references.v1"
    private let maximumReferences = 50

    init(keychain: any SecureKeyValueStore = KeychainStore()) {
        self.keychain = keychain
    }

    func references() -> [TicketAccessReference] {
        guard let encoded = keychain.read(storageKey),
              let data = encoded.data(using: .utf8),
              let references = try? JSONDecoder().decode([TicketAccessReference].self, from: data) else {
            return []
        }
        return references
    }

    @discardableResult
    func add(_ reference: TicketAccessReference) -> Bool {
        var next = references().filter { $0 != reference }
        next.insert(reference, at: 0)
        if next.count > maximumReferences { next.removeLast(next.count - maximumReferences) }
        guard let data = try? JSONEncoder().encode(next),
              let encoded = String(data: data, encoding: .utf8) else { return false }
        do {
            try keychain.save(encoded, for: storageKey)
            return true
        } catch {
            return false
        }
    }

    func remove(_ reference: TicketAccessReference) {
        let next = references().filter { $0 != reference }
        guard !next.isEmpty else {
            keychain.delete(storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(next),
              let encoded = String(data: data, encoding: .utf8) else { return }
        try? keychain.save(encoded, for: storageKey)
    }
}

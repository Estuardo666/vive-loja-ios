import Foundation
import Observation

@MainActor
@Observable
final class DeepLinkRouter {
    struct CheckoutResult: Hashable, Identifiable {
        let token: String
        let clientTransactionId: String
        let status: String

        var id: String { "\(token):\(clientTransactionId):\(status)" }
    }

    enum Destination: Hashable, Identifiable {
        case venue(slug: String)
        case event(slug: String)
        case post(slug: String)
        case watchEvent(slug: String)
        case route(slug: String)
        case collection(slug: String)

        var id: String {
            switch self {
            case .venue(let slug): return "venue:\(slug)"
            case .event(let slug): return "event:\(slug)"
            case .post(let slug): return "post:\(slug)"
            case .watchEvent(let slug): return "watch-event:\(slug)"
            case .route(let slug): return "route:\(slug)"
            case .collection(let slug): return "collection:\(slug)"
            }
        }

        /// Tab the destination belongs to, so a link pushes onto that tab's
        /// stack instead of covering the app with a modal.
        var tab: MainTabView.Tab {
            switch self {
            case .venue, .event, .watchEvent: return .explore
            case .post, .route: return .home
            case .collection: return .saved
            }
        }
    }

    /// Navigation stacks of the tabs a deep link can land on. They live here
    /// rather than in each tab so a link can push onto a stack that is not on
    /// screen yet, and so the pushed screen survives a tab switch. This used to
    /// be a sheet over the whole app, which covered the tab bar and rendered
    /// placeholder models with no way back into context.
    var homePath: [Destination] = []
    var explorePath: [Destination] = []
    var savedPath: [Destination] = []

    /// Set by `handle` and consumed by `MainTabView`, which selects the tab and
    /// appends to the matching path.
    var pendingDestination: Destination?
    var pendingCheckoutResult: CheckoutResult?

    func handle(_ url: URL) {
        let scheme = url.scheme?.lowercased()
        let host = (url.host ?? "").lowercased()
        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }

        let isWebCheckoutResult = (host == "viveloja.com" || host == "www.viveloja.com") && segments == ["checkout", "result"]
        let isAppCheckoutResult = scheme == "viveloja" && host == "checkout" && segments == ["result"]
        if (isWebCheckoutResult || isAppCheckoutResult),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            func value(_ name: String) -> String { components.queryItems?.first(where: { $0.name == name })?.value ?? "" }
            let token = value("token").trimmingCharacters(in: .whitespacesAndNewlines)
            guard token.count >= 20, token.count <= 160 else { return }
            let status = value("status").lowercased()
            pendingCheckoutResult = CheckoutResult(
                token: token,
                clientTransactionId: value("clientTransactionId"),
                status: status.isEmpty ? "pending" : status
            )
            return
        }

        let kind: String?
        let slug: String?

        if scheme == "viveloja" {
            kind = host.isEmpty ? segments.first?.lowercased() : host
            slug = host.isEmpty ? segments.dropFirst().first : segments.first
        } else if host == "viveloja.com" || host == "www.viveloja.com" {
            kind = segments.first?.lowercased()
            slug = segments.dropFirst().first
        } else {
            return
        }

        guard let kind, let slug, !slug.isEmpty else { return }
        guard let resolved = DeepLinkRouter.destination(kind: kind, slug: slug) else { return }
        open(resolved)
    }

    /// Entry point shared by Universal Links, the custom scheme and push
    /// notification taps.
    func open(_ destination: Destination) {
        pendingDestination = destination
    }

    /// Pushes onto the stack of the destination's tab, avoiding a duplicate
    /// push when the same screen is already on top.
    func consumePendingDestination() -> MainTabView.Tab? {
        guard let destination = pendingDestination else { return nil }
        pendingDestination = nil

        switch destination.tab {
        case .home: append(destination, to: &homePath)
        case .explore: append(destination, to: &explorePath)
        case .saved: append(destination, to: &savedPath)
        case .messages, .account: return nil
        }
        return destination.tab
    }

    private func append(_ destination: Destination, to path: inout [Destination]) {
        guard path.last != destination else { return }
        path.append(destination)
    }

    /// Resolves a path segment to a destination. Canonical segments come from
    /// `ShareableKind` so they cannot drift from the backend's
    /// `canonical-urls.ts`; the rest are legacy or English aliases.
    static func destination(kind: String, slug: String) -> Destination? {
        let normalized = kind.lowercased()

        if let match = ShareableKind.allCases.first(where: { $0.pathSegment == normalized }) {
            return destination(for: match, slug: slug)
        }

        switch normalized {
        case "local", "venue", "venues": return .venue(slug: slug)
        case "evento", "event": return .event(slug: slug)
        case "post", "posts": return .post(slug: slug)
        case "transmisiones", "watch-events": return .watchEvent(slug: slug)
        case "ruta", "routes", "route": return .route(slug: slug)
        case "coleccion", "colección", "collections", "collection": return .collection(slug: slug)
        default: return nil
        }
    }

    static func destination(for kind: ShareableKind, slug: String) -> Destination {
        switch kind {
        case .venue: return .venue(slug: slug)
        case .event: return .event(slug: slug)
        case .post: return .post(slug: slug)
        case .watchEvent: return .watchEvent(slug: slug)
        case .route: return .route(slug: slug)
        case .collection: return .collection(slug: slug)
        }
    }
}

import Foundation
import Observation

@MainActor
@Observable
final class DeepLinkRouter {
    enum Destination: Hashable, Identifiable {
        case venue(slug: String)
        case event(slug: String)
        case post(slug: String)

        var id: String {
            switch self {
            case .venue(let slug): return "venue:\(slug)"
            case .event(let slug): return "event:\(slug)"
            case .post(let slug): return "post:\(slug)"
            }
        }
    }

    var destination: Destination?

    func handle(_ url: URL) {
        let host = (url.host ?? "").lowercased()
        let segments = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        let kind: String?
        let slug: String?

        if url.scheme?.lowercased() == "viveloja" {
            kind = host.isEmpty ? segments.first?.lowercased() : host
            slug = host.isEmpty ? segments.dropFirst().first : segments.first
        } else if host == "viveloja.com" || host == "www.viveloja.com" {
            kind = segments.first?.lowercased()
            slug = segments.dropFirst().first
        } else {
            return
        }

        guard let kind, let slug, !slug.isEmpty else { return }
        switch kind {
        case "local", "locales", "venue", "venues": destination = .venue(slug: slug)
        case "evento", "eventos", "event": destination = .event(slug: slug)
        case "blog", "post", "posts": destination = .post(slug: slug)
        default: break
        }
    }
}

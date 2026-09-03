import Foundation

enum AppEnvironment: Sendable {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var baseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "VL_API_BASE_URL") as? String,
           let url = URL(string: configured), !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: "https://viveloja.com/api/mobile/v1")!
    }

    /// The public site behind the same deployment. The mobile API has no
    /// endpoint that returns a post's body — `/content` carries only the
    /// summary fields — so articles are read on the web page, which does.
    /// Derived from `baseURL` so a staging build points at its own site.
    var webBaseURL: URL {
        var url = baseURL
        for _ in 0..<3 where !url.path.isEmpty && url.path != "/" {
            url = url.deletingLastPathComponent()
        }
        return url
    }

    /// APNs environment this build is signed for, injected from
    /// `VL_APS_ENVIRONMENT` — the same build setting that fills the
    /// `aps-environment` entitlement. Registering a sandbox token against the
    /// production gateway (or the reverse) makes every push fail with
    /// BadDeviceToken, and nothing surfaces the mismatch at build time.
    var apnsEnvironment: String {
        let configured = Bundle.main.object(forInfoDictionaryKey: "VL_APS_ENVIRONMENT") as? String
        guard let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines),
              value == "sandbox" || value == "development" || value == "production" else {
            return "production"
        }
        // Apple spells the sandbox "development" in the entitlement; the backend
        // and APNs call it "sandbox".
        return value == "development" ? "sandbox" : value
    }

    /// Public URL of a published article, matching the site's /blog/[slug].
    func articleURL(slug: String) -> URL {
        shareURL(for: .post, slug: slug)
    }

    /// Canonical public URL of a shareable resource. Mirrors
    /// `src/lib/canonical-urls.ts` on the backend: the site, the share sheets,
    /// the push payloads and the Universal Links association file all have to
    /// agree on these paths, or a shared link opens Safari instead of the app.
    func shareURL(for kind: ShareableKind, slug: String) -> URL {
        webBaseURL.appending(path: kind.pathSegment).appending(path: slug)
    }
}

/// Content that has a public web page and can be opened by a Universal Link.
enum ShareableKind: String, Sendable, CaseIterable {
    case venue
    case event
    case post
    case watchEvent
    case route
    case collection

    var pathSegment: String {
        switch self {
        case .venue: return "locales"
        case .event: return "eventos"
        case .post: return "blog"
        case .watchEvent: return "partidos"
        case .route: return "rutas"
        case .collection: return "colecciones"
        }
    }
}

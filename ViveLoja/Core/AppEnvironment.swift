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

    /// Public URL of a published article, matching the site's /blog/[slug].
    func articleURL(slug: String) -> URL {
        webBaseURL.appending(path: "blog").appending(path: slug)
    }
}

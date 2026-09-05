import Foundation

struct GoogleVenuePhoto: Decodable, Sendable {
    struct Author: Decodable, Sendable {
        let displayName: String
        let uri: URL?
    }
    let photoUri: URL
    let googleMapsUri: URL
    let authors: [Author]
}

struct GoogleVenuePhotoResponse: Decodable, Sendable {
    let photo: GoogleVenuePhoto?
}

/// No API key, photo reference, metadata or image is persisted on the device.
///
/// Results are held in memory for `ttl` so that revisiting a venue within one
/// session does not re-fetch. The store lives on the instance, never on disk,
/// so it dies with the app — Google's terms forbid persisting photo content,
/// and the `photoUri` is a short-lived signed URL that would break long before
/// any storage limit applied. `ttl` sits far below that lifetime.
actor GoogleVenuePhotoClient {
    static let shared = GoogleVenuePhotoClient()
    private let session: URLSession
    private let environment: AppEnvironment

    private struct CacheEntry {
        let result: (GoogleVenuePhoto, Data)?
        let storedAt: Date
        let expiresAt: Date
        var cost: Int { result?.1.count ?? 0 }
    }

    /// Well under the signed URL's lifetime, so a hit is never a dead link.
    private let ttl: TimeInterval = 5 * 60
    /// Full-size JPEGs add up; evict rather than grow without bound.
    private let maxBytes = 24 * 1024 * 1024
    private let maxEntries = 60

    private var cache: [String: CacheEntry] = [:]
    /// In-flight loads, so views appearing together fetch once. These are
    /// unstructured tasks: one view disappearing must not cancel the others.
    private var inflight: [String: Task<(GoogleVenuePhoto, Data)?, Error>] = [:]

    init(environment: AppEnvironment = .current, session: URLSession? = nil) {
        self.environment = environment
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        self.session = session ?? URLSession(configuration: configuration)
    }

    func load(slug: String, large: Bool) async throws -> (GoogleVenuePhoto, Data)? {
        guard !slug.isEmpty, !slug.contains("/"), slug != ".", slug != ".." else { return nil }
        let key = "\(slug)-\(large)"

        if let entry = cache[key], entry.expiresAt > Date() { return entry.result }

        if let running = inflight[key] { return try await running.value }

        let task = Task { try await self.fetch(slug: slug, large: large) }
        inflight[key] = task
        defer { inflight[key] = nil }

        // A venue with no photo is worth remembering too. Failures are not
        // stored, so the next appearance retries.
        let result = try await task.value
        store(result, forKey: key)
        return result
    }

    /// Drops an entry after the image fails to decode or display.
    func invalidate(slug: String, large: Bool) {
        cache.removeValue(forKey: "\(slug)-\(large)")
    }

    private func store(_ result: (GoogleVenuePhoto, Data)?, forKey key: String) {
        let now = Date()
        cache[key] = CacheEntry(result: result, storedAt: now, expiresAt: now.addingTimeInterval(ttl))
        cache = cache.filter { $0.value.expiresAt > now }
        // Oldest first, until both bounds are satisfied.
        while cache.count > maxEntries || cache.values.reduce(0, { $0 + $1.cost }) > maxBytes {
            guard let oldest = cache.min(by: { $0.value.storedAt < $1.value.storedAt })?.key else { break }
            cache.removeValue(forKey: oldest)
        }
    }

    private func fetch(slug: String, large: Bool) async throws -> (GoogleVenuePhoto, Data)? {
        let endpoint = environment.webBaseURL.appending(path: "api/venues")
            .appending(component: slug).appending(path: "google-photo")
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "size", value: large ? "large" : "small")]
        guard let url = components?.url else { throw URLError(.badURL) }
        let metadata = try await data(from: url)
        guard let photo = try JSONDecoder().decode(GoogleVenuePhotoResponse.self, from: metadata).photo,
              photo.photoUri.scheme == "https", photo.googleMapsUri.scheme == "https" else { return nil }
        try Task.checkCancellation()
        return (photo, try await data(from: photo.photoUri))
    }

    private func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

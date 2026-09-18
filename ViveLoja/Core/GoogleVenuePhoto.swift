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
/// Google content is never cached. The only retained state is an in-flight
/// task, so views appearing together share one metadata lookup and one image
/// download; once that task finishes, its result is released.
actor GoogleVenuePhotoClient {
    static let shared = GoogleVenuePhotoClient()
    private let session: URLSession
    private let environment: AppEnvironment

    /// In-flight loads, so views appearing together fetch once. These are
    /// unstructured tasks: one view disappearing must not cancel the others.
    private var inflight: [String: Task<(GoogleVenuePhoto, Data)?, Error>] = [:]

    init(environment: AppEnvironment = .current, session: URLSession? = nil) {
        self.environment = environment
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        self.session = session ?? URLSession(configuration: configuration)
    }

    func load(slug: String, large: Bool) async throws -> (GoogleVenuePhoto, Data)? {
        guard !slug.isEmpty, !slug.contains("/"), slug != ".", slug != ".." else { return nil }
        let key = "\(slug)-\(large)"

        if let running = inflight[key] { return try await running.value }

        let task = Task { try await self.fetch(slug: slug, large: large) }
        inflight[key] = task
        defer { inflight[key] = nil }

        return try await task.value
    }

    /// Kept as a source-compatible no-op for callers that invalidate a failed
    /// image. There is no Google content cache to invalidate.
    func invalidate(slug: String, large: Bool) {
        _ = (slug, large)
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

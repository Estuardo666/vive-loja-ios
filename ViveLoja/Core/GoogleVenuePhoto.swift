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
actor GoogleVenuePhotoClient {
    static let shared = GoogleVenuePhotoClient()
    private let session: URLSession
    private let environment: AppEnvironment

    init(environment: AppEnvironment = .current, session: URLSession? = nil) {
        self.environment = environment
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 20
        self.session = session ?? URLSession(configuration: configuration)
    }

    func load(slug: String, large: Bool) async throws -> (GoogleVenuePhoto, Data)? {
        guard !slug.isEmpty, !slug.contains("/"), slug != ".", slug != ".." else { return nil }
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

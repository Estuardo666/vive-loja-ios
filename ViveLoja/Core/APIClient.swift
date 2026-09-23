import Foundation

enum APIError: LocalizedError, Sendable {
    case invalidURL
    case transport(String)
    case server(code: String, message: String, status: Int)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "La dirección del servicio no es válida."
        case .transport(let message): return message
        case .server(_, let message, _): return message
        case .decoding: return "La respuesta del servicio no se pudo interpretar."
        }
    }
}

struct APIEnvelope<Value: Decodable & Sendable>: Decodable, Sendable {
    let data: Value
    let meta: [String: JSONValue]?
}

enum JSONValue: Decodable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }
}

actor APIClient {
    static let shared = APIClient()
    private let session: URLSession
    private let environment: AppEnvironment
    private let decoder: JSONDecoder

    private struct PublicCacheEntry: Sendable {
        let data: Data
        let storedAt: Date
        let freshUntil: Date
        let staleUntil: Date
        var cost: Int { data.count }
    }

    /// Public responses are safe to keep only in memory. This avoids putting
    /// account data in URLCache while still making repeated home/explore/list
    /// loads instant during the current session.
    private var publicCache: [String: PublicCacheEntry] = [:]
    private var publicInflight: [String: Task<Data, Error>] = [:]
    private let publicFreshLifetime: TimeInterval = 30
    private let publicStaleLifetime: TimeInterval = 5 * 60
    private let publicCacheMaxEntries = 40
    private let publicCacheMaxBytes = 16 * 1024 * 1024

    init(environment: AppEnvironment = .current, session: URLSession? = nil) {
        self.environment = environment
        self.session = session ?? Self.makeSession()
        self.decoder = .viveLoja
    }

    /// The client owns a small in-memory public cache, so the URL session does
    /// not need a disk cache at all. That makes the no-persistence guarantee
    /// for bearer requests independent of server response headers. Venue detail
    /// responses are cached only after Google-derived fields are stripped.
    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 30
        configuration.httpMaximumConnectionsPerHost = 8
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        return URLSession(configuration: configuration)
    }

    func get<Value: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [], bearer: String? = nil) async throws -> Value {
        try await request(path, method: "GET", query: query, body: Optional<String>.none, bearer: bearer)
    }

    /// The first-party venue DTO may come from memory. Fetch the live response
    /// as a follow-up for Google's attributed fields, which are never cached.
    func getFreshPublic<Value: Decodable & Sendable>(_ path: String) async throws -> Value {
        try await request(path, method: "GET", query: [], body: Optional<String>.none,
                          bearer: nil, forceFreshPublic: true)
    }

    func hasCachedPublic(_ path: String) -> Bool {
        let url = environment.baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        guard let entry = publicCache[url.absoluteString] else { return false }
        return entry.staleUntil > Date()
    }

    func post<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil, headers: [String: String] = [:]) async throws -> Value {
        try await request(path, method: "POST", query: [], body: body, bearer: bearer, headers: headers)
    }

    func post<Value: Decodable & Sendable>(_ path: String, bearer: String? = nil, headers: [String: String] = [:]) async throws -> Value {
        try await request(path, method: "POST", query: [], body: Optional<String>.none, bearer: bearer, headers: headers)
    }

    func patch<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "PATCH", query: [], body: body, bearer: bearer)
    }

    func put<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "PUT", query: [], body: body, bearer: bearer)
    }

    func upload<Value: Decodable & Sendable>(_ path: String, data: Data, fileName: String, mimeType: String, bearer: String? = nil) async throws -> Value {
        guard var components = URLComponents(url: environment.baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false), let url = components.url else { throw APIError.invalidURL }
        components.queryItems = nil
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
            request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        }
        let safeFileName = fileName.replacingOccurrences(of: "\"", with: "")
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        request.httpBody = body
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Respuesta inválida del servicio.") }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIError.server(code: envelope?.error.code ?? "HTTP_\(http.statusCode)", message: envelope?.error.message ?? "No se pudo subir el archivo.", status: http.statusCode)
        }
        do {
            if let wrapped = try? decoder.decode(APIEnvelope<Value>.self, from: data) { return wrapped.data }
            return try decoder.decode(Value.self, from: data)
        } catch { throw APIError.decoding(error.localizedDescription) }
    }

    func delete<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "DELETE", query: [], body: body, bearer: bearer)
    }

    private func request<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, method: String, query: [URLQueryItem], body: Body?, bearer: String?, headers: [String: String] = [:], forceFreshPublic: Bool = false) async throws -> Value {
        guard var components = URLComponents(url: environment.baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if bearer != nil { request.setValue("no-store", forHTTPHeaderField: "Cache-Control") }
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        // Callers may add headers such as Idempotency-Key, but never get to
        // weaken the no-persistence rule for an authenticated request.
        if bearer != nil { request.setValue("no-store", forHTTPHeaderField: "Cache-Control") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }

        if method == "GET", bearer == nil, isPublicCacheable(path: path) {
            let cacheKey = url.absoluteString
            let data: Data
            if forceFreshPublic {
                data = try await refreshPublicData(for: request, key: cacheKey, stripGoogleContent: isVenueDetail(path: path))
            } else {
                data = try await publicData(for: request, key: cacheKey, stripGoogleContent: isVenueDetail(path: path))
            }
            return try decode(data, as: Value.self)
        }

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Respuesta inválida del servicio.") }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIError.server(code: envelope?.error.code ?? "HTTP_\(http.statusCode)", message: envelope?.error.message ?? "No se pudo completar la solicitud.", status: http.statusCode)
        }
        if http.statusCode == 204 { return try decodeEmpty(Value.self) }
        do {
            if let wrapped = try? decoder.decode(APIEnvelope<Value>.self, from: data) { return wrapped.data }
            return try decoder.decode(Value.self, from: data)
        } catch { throw APIError.decoding(error.localizedDescription) }
    }

    private func decodeEmpty<Value: Decodable & Sendable>(_ type: Value.Type) throws -> Value {
        if Value.self == EmptyResponse.self, let value = EmptyResponse() as? Value { return value }
        throw APIError.decoding("Respuesta vacía")
    }

    private func decode<Value: Decodable & Sendable>(_ data: Data, as type: Value.Type) throws -> Value {
        do {
            if let wrapped = try? decoder.decode(APIEnvelope<Value>.self, from: data) { return wrapped.data }
            return try decoder.decode(Value.self, from: data)
        } catch { throw APIError.decoding(error.localizedDescription) }
    }

    private func isPublicCacheable(path: String) -> Bool {
        let normalizedPath = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let privatePrefixes = ["/me/", "/admin/", "/auth/", "/ticketing/", "/views/", "/uploads/"]
        guard !privatePrefixes.contains(where: { normalizedPath.hasPrefix($0) }) else { return false }
        // The Google photo proxy returns photo URI and attribution metadata;
        // it must remain uncached even though it sits below /venues/.
        return !normalizedPath.hasSuffix("/google-photo")
    }

    private func isVenueDetail(path: String) -> Bool {
        let normalizedPath = "/" + path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return normalizedPath.hasPrefix("/venues/") && !normalizedPath.hasSuffix("/google-photo")
    }

    private func publicData(for request: URLRequest, key: String, stripGoogleContent: Bool) async throws -> Data {
        let now = Date()
        if let entry = publicCache[key] {
            if entry.freshUntil > now {
                return entry.data
            }
            if entry.staleUntil > now {
                schedulePublicRefresh(for: request, key: key, stripGoogleContent: stripGoogleContent)
                return entry.data
            }
            publicCache.removeValue(forKey: key)
        }
        return try await refreshPublicData(for: request, key: key, stripGoogleContent: stripGoogleContent)
    }

    /// Returns a stale public response immediately and refreshes it in the
    /// background. The in-flight map also deduplicates cold concurrent loads.
    private func schedulePublicRefresh(for request: URLRequest, key: String, stripGoogleContent: Bool) {
        guard publicInflight[key] == nil else { return }
        Task { [weak self] in
            _ = try? await self?.refreshPublicData(
                for: request,
                key: key,
                stripGoogleContent: stripGoogleContent
            )
        }
    }

    private func refreshPublicData(for request: URLRequest, key: String, stripGoogleContent: Bool) async throws -> Data {
        if let running = publicInflight[key] {
            return try await running.value
        }

        let task = Task { [weak self] in
            guard let self else { throw APIError.transport("La sesión de red no está disponible.") }
            return try await self.networkData(for: request)
        }
        publicInflight[key] = task

        do {
            let data = try await task.value
            publicInflight[key] = nil
            storePublicData(
                stripGoogleContent ? Self.removingGoogleContent(from: data) : data,
                for: key
            )
            return data
        } catch {
            publicInflight[key] = nil
            throw error
        }
    }

    private func storePublicData(_ data: Data, for key: String) {
        let now = Date()
        publicCache[key] = PublicCacheEntry(
            data: data,
            storedAt: now,
            freshUntil: now.addingTimeInterval(publicFreshLifetime),
            staleUntil: now.addingTimeInterval(publicStaleLifetime)
        )
        publicCache = publicCache.filter { $0.value.staleUntil > now }
        while publicCache.count > publicCacheMaxEntries || publicCache.values.reduce(0, { $0 + $1.cost }) > publicCacheMaxBytes {
            guard let oldest = publicCache.min(by: { $0.value.storedAt < $1.value.storedAt })?.key else { break }
            publicCache.removeValue(forKey: oldest)
        }
    }

    /// Google Place Photos and photo-derived content are not retained in the
    /// app cache. Venue details can still be reused immediately on back-nav by
    /// removing every Google-prefixed field before storing the public response.
    private static func removingGoogleContent(from data: Data) -> Data {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let sanitized = removingGoogleContent(from: object),
              JSONSerialization.isValidJSONObject(sanitized),
              let result = try? JSONSerialization.data(withJSONObject: sanitized)
        else { return data }
        return result
    }

    private static func removingGoogleContent(from value: Any) -> Any? {
        if let dictionary = value as? [String: Any] {
            return dictionary.reduce(into: [String: Any]()) { result, entry in
                guard !entry.key.lowercased().hasPrefix("google") else { return }
                if let sanitized = removingGoogleContent(from: entry.value) {
                    result[entry.key] = sanitized
                }
            }
        }
        if let array = value as? [Any] {
            return array.compactMap { removingGoogleContent(from: $0) }
        }
        return value
    }

    private func networkData(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw APIError.transport(error.localizedDescription) }
        guard let http = response as? HTTPURLResponse else { throw APIError.transport("Respuesta inválida del servicio.") }
        guard (200..<300).contains(http.statusCode) else {
            let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data)
            throw APIError.server(code: envelope?.error.code ?? "HTTP_\(http.statusCode)", message: envelope?.error.message ?? "No se pudo completar la solicitud.", status: http.statusCode)
        }
        return data
    }
}

private struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
    struct APIErrorBody: Decodable { let code: String; let message: String }
}

/// The one decoder every response goes through, including the message
/// stream, so no caller can drift back onto a stricter date strategy.
extension JSONDecoder {
    /// Every timestamp the API returns comes from Prisma by way of
    /// `Date.prototype.toJSON`, so it always carries milliseconds:
    /// `2026-02-23T06:14:16.251Z`. `JSONDecoder.DateDecodingStrategy.iso8601`
    /// is `ISO8601DateFormatter` with `.withInternetDateTime` only, and that
    /// rejects fractional seconds outright — so any model with a non-optional
    /// `Date` failed to decode, and any optional one threw as soon as the field
    /// was non-null. That is what emptied the Cuenta screen: a profile with
    /// `onboardingCompletedAt` set could not be parsed at all, and `/me/badges`
    /// is behind a `try?` so it silently came back empty.
    ///
    /// Accept both shapes; the server is free to omit the milliseconds.
    static var viveLoja: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = try? Date(value, strategy: .iso8601.time(includingFractionalSeconds: true)) { return date }
            if let date = try? Date(value, strategy: .iso8601) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Fecha ISO8601 no reconocida: \(value)"
            )
        }
        return decoder
    }
}

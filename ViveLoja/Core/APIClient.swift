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

    init(environment: AppEnvironment = .current, session: URLSession = .shared) {
        self.environment = environment
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func get<Value: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [], bearer: String? = nil) async throws -> Value {
        try await request(path, method: "GET", query: query, body: Optional<String>.none, bearer: bearer)
    }

    func post<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "POST", query: [], body: body, bearer: bearer)
    }

    func post<Value: Decodable & Sendable>(_ path: String, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "POST", query: [], body: Optional<String>.none, bearer: bearer)
    }

    func patch<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "PATCH", query: [], body: body, bearer: bearer)
    }

    func delete<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, body: Body, bearer: String? = nil) async throws -> Value {
        try await request(path, method: "DELETE", query: [], body: body, bearer: bearer)
    }

    private func request<Body: Encodable & Sendable, Value: Decodable & Sendable>(_ path: String, method: String, query: [URLQueryItem], body: Body?, bearer: String?) async throws -> Value {
        guard var components = URLComponents(url: environment.baseURL.appending(path: path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else { throw APIError.invalidURL }
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONEncoder().encode(body) }

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
}

private struct APIErrorEnvelope: Decodable {
    let error: APIErrorBody
    struct APIErrorBody: Decodable { let code: String; let message: String }
}

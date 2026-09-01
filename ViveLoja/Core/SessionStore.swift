import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private let keychain = KeychainStore()
    private let api = APIClient.shared
    private(set) var user: MobileUser?
    private(set) var accessToken: String?
    private var refreshToken: String?
    private(set) var isRestoring = true
    var errorMessage: String?

    func restore() async {
        defer { isRestoring = false }
        guard let access = keychain.read("accessToken"), let refresh = keychain.read("refreshToken") else { return }
        accessToken = access; refreshToken = refresh
        if let stored = keychain.read("user"), let data = stored.data(using: .utf8), let decoded = try? JSONDecoder().decode(MobileUser.self, from: data) { user = decoded }
    }

    func login(email: String, password: String) async -> Bool {
        do { let tokens: MobileTokens = try await api.post("/auth/login", body: LoginRequest(email: email, password: password)); persist(tokens); return true }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo iniciar sesión."; return false }
    }

    func register(name: String, email: String, password: String) async -> Bool {
        do { let tokens: MobileTokens = try await api.post("/auth/register", body: RegisterRequest(name: name, email: email, password: password)); persist(tokens); return true }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo crear la cuenta."; return false }
    }

    func loginWithApple(identityToken: String, nonce: String?, name: String?) async -> Bool {
        do {
            let tokens: MobileTokens = try await api.post("/auth/apple", body: AppleLoginRequest(identityToken: identityToken, nonce: nonce, name: name))
            persist(tokens)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo iniciar sesión con Apple."
            return false
        }
    }

    func signOut() {
        let token = refreshToken
        clear()
        guard let token else { return }
        Task {
            let _: EmptyResponse? = try? await api.post("/auth/logout", body: RefreshRequest(refreshToken: token))
        }
    }

    private func persist(_ tokens: MobileTokens) {
        accessToken = tokens.accessToken; refreshToken = tokens.refreshToken; user = tokens.user; errorMessage = nil
        VLFeedback.success()
        try? keychain.save(tokens.accessToken, for: "accessToken")
        try? keychain.save(tokens.refreshToken, for: "refreshToken")
        if let data = try? JSONEncoder().encode(tokens.user), let value = String(data: data, encoding: .utf8) { try? keychain.save(value, for: "user") }
    }

    private func clear() {
        user = nil; accessToken = nil; refreshToken = nil
        keychain.delete("accessToken"); keychain.delete("refreshToken"); keychain.delete("user")
    }
}

struct EmptyResponse: Decodable, Sendable {}

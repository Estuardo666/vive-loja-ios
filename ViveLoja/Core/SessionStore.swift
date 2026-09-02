import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private let keychain: any SecureKeyValueStore
    private let api: APIClient
    private(set) var user: MobileUser?
    private(set) var accessToken: String?
    private var refreshToken: String?
    private(set) var isRestoring = true
    /// Cached avatar so the tab bar and the map pin can show it without each
    /// screen refetching the profile.
    private(set) var avatarURL: URL?
    var isSessionExpired = false
    var errorMessage: String?

    init(api: APIClient = .shared, keychain: any SecureKeyValueStore = KeychainStore()) {
        self.api = api
        self.keychain = keychain
    }

    func restore() async {
        defer { isRestoring = false }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-authenticated") {
            user = MobileUser(id: "ui-test-user", name: "Usuario de prueba", email: "demo@viveloja.test", role: "USER")
            accessToken = "ui-testing-access-token"
            refreshToken = "ui-testing-refresh-token"
            return
        }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting-expired-session") {
            isSessionExpired = true
            return
        }
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

    @discardableResult
    func refresh() async -> Bool {
        guard let refreshToken else { return false }
        do {
            let tokens: MobileTokens = try await api.post("/auth/refresh", body: RefreshRequest(refreshToken: refreshToken))
            persist(tokens)
            return true
        } catch let error as APIError {
            if case .server(_, _, let status) = error, status == 401 {
                clear()
                isSessionExpired = true
            }
            errorMessage = error.errorDescription ?? "Tu sesión ya no es válida."
            return false
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo renovar la sesión."
            return false
        }
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

    /// Best-effort: a missing avatar simply leaves the default glyph in place.
    func loadAvatar() async {
        guard let accessToken else { avatarURL = nil; return }
        let profile: MobileProfile? = try? await api.get("/me/profile", bearer: accessToken)
        avatarURL = profile?.image
    }

    private func persist(_ tokens: MobileTokens) {
        accessToken = tokens.accessToken; refreshToken = tokens.refreshToken; user = tokens.user; errorMessage = nil
        isSessionExpired = false
        VLFeedback.success()
        Task { await loadAvatar() }
        try? keychain.save(tokens.accessToken, for: "accessToken")
        try? keychain.save(tokens.refreshToken, for: "refreshToken")
        if let data = try? JSONEncoder().encode(tokens.user), let value = String(data: data, encoding: .utf8) { try? keychain.save(value, for: "user") }
    }

    private func clear() {
        user = nil; accessToken = nil; refreshToken = nil; avatarURL = nil
        keychain.delete("accessToken"); keychain.delete("refreshToken"); keychain.delete("user")
    }
}

struct EmptyResponse: Decodable, Sendable {}

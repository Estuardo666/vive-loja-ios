import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var appleNonce = ""

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "map.fill").font(.system(size: 42, weight: .bold)).foregroundStyle(VLTheme.indigo)
                        Text(mode == .login ? "Bienvenido de vuelta" : "Crea tu cuenta").font(.largeTitle.weight(.bold))
                        Text("Descubre lo mejor de Loja.").foregroundStyle(.secondary)
                    }
                    .padding(.top, 28)

                    VStack(spacing: 12) {
                        if mode == .register { TextField("Nombre", text: $name).textContentType(.name).textFieldStyle(.roundedBorder) }
                        TextField("Correo electrónico", text: $email).textContentType(.emailAddress).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
                        SecureField("Contraseña", text: $password).textContentType(mode == .login ? .password : .newPassword).textFieldStyle(.roundedBorder)
                        if let message = session.errorMessage { Text(message).font(.footnote).foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading) }
                        Button(action: submit) {
                            Group { if isSubmitting { ProgressView().tint(.white) } else { Text(mode == .login ? "Iniciar sesión" : "Crear cuenta") } }
                                .frame(maxWidth: .infinity).padding(.vertical, 13)
                        }
                        .buttonStyle(.borderedProminent).tint(VLTheme.indigo).disabled(isSubmitting)
                    }
                    .padding(18).vlGlass()

                    HStack { Rectangle().frame(height: 1).foregroundStyle(.quaternary); Text("o").foregroundStyle(.secondary); Rectangle().frame(height: 1).foregroundStyle(.quaternary) }
                    SignInWithAppleButton(.signIn, onRequest: { request in
                        let nonce = Self.randomNonce()
                        appleNonce = nonce
                        request.requestedScopes = [.fullName, .email]
                        request.nonce = Self.sha256(nonce)
                    }, onCompletion: { result in
                        Task { @MainActor in await handleApple(result) }
                    })
                        .signInWithAppleButtonStyle(.black).frame(height: 48).clipShape(RoundedRectangle(cornerRadius: 12))
                    Button(mode == .login ? "¿No tienes cuenta? Regístrate" : "Ya tengo una cuenta") { mode = mode == .login ? .register : .login }
                        .font(.subheadline.weight(.semibold))
                }
                .padding(20)
            }
            .navigationTitle("Cuenta")
        }
    }

    private func submit() {
        isSubmitting = true
        Task { @MainActor in
            defer { isSubmitting = false }
            if mode == .login { _ = await session.login(email: email, password: password) }
            else { _ = await session.register(name: name, email: email, password: password) }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, any Error>) async {
        do {
            let authorization = try result.get()
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let token = String(data: identityToken, encoding: .utf8),
                  !appleNonce.isEmpty else {
                throw AppleAuthError.invalidCredential
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            isSubmitting = true
            defer { isSubmitting = false }
            _ = await session.loginWithApple(identityToken: token, nonce: Self.sha256(appleNonce), name: name.isEmpty ? nil : name)
        } catch {
            session.errorMessage = "No se pudo completar el acceso con Apple."
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var byte: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &byte) == errSecSuccess else {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            if Int(byte) < characters.count {
                result.append(characters[Int(byte)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private enum AppleAuthError: Error { case invalidCredential }

import AuthenticationServices
import SwiftUI

struct AuthView: View {
    @Environment(SessionStore.self) private var session
    @State private var mode: Mode = .login
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

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
                    SignInWithAppleButton(.signIn, onRequest: { request in request.requestedScopes = [.fullName, .email] }, onCompletion: { _ in })
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
}

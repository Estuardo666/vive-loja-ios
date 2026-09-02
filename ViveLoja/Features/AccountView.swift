import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class AccountViewModel {
    var profile: MobileProfile?
    var badges: [MobileBadge] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { profile = nil; return }
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await APIClient.shared.get("/me/profile", bearer: accessToken)
            badges = (try? await APIClient.shared.get("/me/badges", bearer: accessToken)) ?? []
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar tu perfil."
        }
    }

    func save(name: String, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            profile = try await APIClient.shared.patch("/me/profile", body: ProfileUpdateRequest(name: name, image: profile?.image), bearer: accessToken)
            errorMessage = nil
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar tu perfil."
            VLFeedback.error()
            return false
        }
    }

    func uploadAvatar(_ data: Data, fileName: String, mimeType: String, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        isSaving = true; defer { isSaving = false }
        do {
            let upload: MobileUpload = try await APIClient.shared.upload("/me/uploads", data: data, fileName: fileName, mimeType: mimeType, bearer: accessToken)
            profile = try await APIClient.shared.patch("/me/profile", body: ProfileUpdateRequest(name: profile?.name, image: upload.url), bearer: accessToken)
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo actualizar tu avatar."
            VLFeedback.error()
            return false
        }
    }

    func changePassword(current: String, new: String, confirm: String, accessToken: String?) async -> Bool {
        guard let accessToken else { return false }
        isSaving = true
        defer { isSaving = false }
        do {
            let _: PasswordUpdateResponse = try await APIClient.shared.patch(
                "/me/password",
                body: PasswordChangeRequest(currentPassword: current, newPassword: new, confirmPassword: confirm),
                bearer: accessToken
            )
            errorMessage = nil
            VLFeedback.success()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cambiar tu contraseña."
            VLFeedback.error()
            return false
        }
    }
}

private struct PasswordUpdateResponse: Decodable, Sendable { let updated: Bool }

struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ThemeStore.self) private var theme
    @State private var showAuth = false
    @State private var showPasswordSheet = false
    @State private var model = AccountViewModel()
    @State private var draftName = ""
    @State private var selectedAvatar: PhotosPickerItem?

    var body: some View {
        @Bindable var theme = theme

        NavigationStack {
            List {
                if let user = session.user {
                    Section {
                        HStack(spacing: 12) {
                            if let image = model.profile?.image {
                                AsyncImage(url: image) { image in image.resizable().scaledToFill() } placeholder: { Image(systemName: "person.crop.circle.fill").resizable() }
                                    .frame(width: 52, height: 52).clipShape(Circle())
                            } else {
                                Image(systemName: "person.crop.circle.fill").font(.system(size: 48)).foregroundStyle(VLTheme.indigo)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(model.profile?.name ?? user.name ?? user.email).font(.headline)
                                Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        PhotosPicker(selection: $selectedAvatar, matching: .images, photoLibrary: .shared()) {
                            Label("Cambiar foto de perfil", systemImage: "camera.fill")
                        }
                        .disabled(model.isSaving || session.accessToken == nil)
                        if model.isLoading { ProgressView().controlSize(.small) }
                    }
                    Section("Perfil") {
                        TextField("Tu nombre", text: $draftName)
                            .textContentType(.name)
                        Button {
                            Task { _ = await model.save(name: draftName, accessToken: session.accessToken) }
                        } label: {
                            if model.isSaving { ProgressView() } else { Label("Guardar cambios", systemImage: "checkmark") }
                        }
                        .disabled(model.isSaving || draftName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
                    }
                    if let error = model.errorMessage {
                        Section { Text(error).foregroundStyle(.red) }
                    }
                    Section("Tu actividad") {
                        NavigationLink(destination: SavedView()) {
                            Label("Mis favoritos", systemImage: "heart")
                        }
                        NavigationLink(destination: CollectionsView()) {
                            Label("Mis colecciones", systemImage: "folder")
                        }
                        NavigationLink(destination: InterestsView()) {
                            Label("Mis intereses", systemImage: "sparkles")
                        }
                        NavigationLink(destination: ReservationsView()) {
                            Label("Mis reservas", systemImage: "calendar.badge.clock")
                        }
                        NavigationLink(destination: MyPublicationsView()) {
                            Label("Mis publicaciones", systemImage: "doc.text.magnifyingglass")
                        }
                        .accessibilityIdentifier("my-publications")
                        NavigationLink(destination: CreationHubView()) {
                            Label("Publicar contenido", systemImage: "square.and.pencil")
                        }
                        .accessibilityIdentifier("creation-hub")
                    }
                    Section("Insignias") {
                        if model.badges.isEmpty {
                            Text("Completa reseñas y check-ins para ganar tus primeras insignias.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        } else {
                            ForEach(model.badges) { badge in
                                Label {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(badge.name).font(.subheadline.weight(.semibold))
                                        Text(badge.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                } icon: {
                                    Text(badge.icon ?? "🏅").font(.title3)
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                    Section("Seguridad") {
                        Button("Cambiar contraseña", systemImage: "lock.rotation") { showPasswordSheet = true }
                            .disabled(model.isSaving || session.accessToken == nil)
                    }
                    Section {
                        Button("Cerrar sesión", role: .destructive) { session.signOut() }
                    }
                } else {
                    Section {
                        Button("Inicia sesión o regístrate") { showAuth = true }
                        Text("Guarda lugares, recibe recomendaciones y publica en Loja.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                Section("Apariencia") {
                    Picker("Paleta", selection: $theme.palette) {
                        ForEach(VLPalette.allCases) { palette in
                            Text(palette.label).tag(palette)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    .accessibilityIdentifier("palette-picker")
                    Text(theme.palette.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cuenta")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(isPresented: $showAuth) { AuthView() }
            .sheet(isPresented: $showPasswordSheet) {
                ChangePasswordView(model: model, accessToken: session.accessToken)
                    .presentationDetents([.medium])
            }
            .task(id: session.user?.id) {
                guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
                await session.refreshIfNeeded()
                await model.load(accessToken: session.accessToken)
                draftName = model.profile?.name ?? session.user?.name ?? ""
            }
            .onChange(of: selectedAvatar) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        _ = await model.uploadAvatar(data, fileName: "avatar.jpg", mimeType: "image/jpeg", accessToken: session.accessToken)
                    }
                }
            }
        }
    }
}

private struct ChangePasswordView: View {
    let model: AccountViewModel
    let accessToken: String?
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    private var isValid: Bool {
        currentPassword.isEmpty == false && newPassword.count >= 8 && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contraseña actual") {
                    SecureField("Contraseña actual", text: $currentPassword)
                }
                Section("Nueva contraseña") {
                    SecureField("Mínimo 8 caracteres", text: $newPassword)
                    SecureField("Repite la nueva contraseña", text: $confirmPassword)
                }
                if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                Button {
                    Task {
                        if await model.changePassword(current: currentPassword, new: newPassword, confirm: confirmPassword, accessToken: accessToken) {
                            dismiss()
                        }
                    }
                } label: {
                    if model.isSaving { ProgressView() } else { Label("Actualizar contraseña", systemImage: "checkmark") }
                }
                .disabled(!isValid || model.isSaving)
            }
            .navigationTitle("Seguridad")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

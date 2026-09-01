import Observation
import SwiftUI

@MainActor
@Observable
final class AccountViewModel {
    var profile: MobileProfile?
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func load(accessToken: String?) async {
        guard let accessToken else { profile = nil; return }
        isLoading = true
        defer { isLoading = false }
        do {
            profile = try await APIClient.shared.get("/me/profile", bearer: accessToken)
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
}

struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false
    @State private var model = AccountViewModel()
    @State private var draftName = ""

    var body: some View {
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
                        Label("Mis favoritos", systemImage: "heart")
                        Label("Mis colecciones", systemImage: "folder")
                        NavigationLink(destination: InterestsView()) {
                            Label("Mis intereses", systemImage: "sparkles")
                        }
                        NavigationLink(destination: ReservationsView()) {
                            Label("Mis reservas", systemImage: "calendar.badge.clock")
                        }
                        NavigationLink(destination: CreateEventView()) {
                            Label("Publicar evento", systemImage: "square.and.pencil")
                        }
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
            }
            .navigationTitle("Cuenta")
            .sheet(isPresented: $showAuth) { AuthView() }
            .task(id: session.user?.id) {
                await model.load(accessToken: session.accessToken)
                draftName = model.profile?.name ?? session.user?.name ?? ""
            }
        }
    }
}

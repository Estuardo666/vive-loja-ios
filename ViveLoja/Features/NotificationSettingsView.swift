import SwiftUI

@MainActor
@Observable
final class NotificationSettingsViewModel {
    var preferences = NotificationPreferences.defaults
    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            preferences = try await api.get("/me/notification-preferences", bearer: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus preferencias."
        }
    }

    /// Saves the whole row: the endpoint accepts a partial body, but sending
    /// everything keeps the screen and the server in step after a failed save.
    func save(token: String?) async {
        guard let token else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            preferences = try await api.patch("/me/notification-preferences", body: preferences, bearer: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron guardar tus preferencias."
        }
    }
}

/// Notification settings. Edits the same row the web dashboard does, so turning
/// something off here silences it on every surface.
struct NotificationSettingsView: View {
    @Environment(SessionStore.self) private var session
    @Environment(PushService.self) private var push
    @State private var model = NotificationSettingsViewModel()

    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                switch push.authorization {
                case .authorized:
                    Label("Notificaciones permitidas en este iPhone", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                case .notDetermined:
                    Button("Permitir notificaciones") {
                        Task { await push.requestAuthorization() }
                    }
                case .denied:
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Las notificaciones están desactivadas para Vive Loja.")
                            .font(.subheadline)
                        Button("Abrir Ajustes") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } header: {
                Text("Permiso del sistema")
            } footer: {
                Text("Sin este permiso no llegan avisos aunque las preferencias estén activas.")
            }

            Section("General") {
                Toggle("Notificaciones activas", isOn: $model.preferences.enabled)
                Toggle("Push", isOn: $model.preferences.pushEnabled)
                Toggle("Correo", isOn: $model.preferences.emailEnabled)
            }

            Section("Qué quieres recibir") {
                Toggle("Recordatorios de eventos guardados", isOn: $model.preferences.eventReminders)
                Toggle("Novedades de locales que sigues", isOn: $model.preferences.newFollowedVenuePost)
                Toggle("Respuestas a mis reseñas", isOn: $model.preferences.reviewReply)
                Toggle("Mensajes nuevos", isOn: $model.preferences.messageReceived)
                Toggle("Estado de mis reclamos", isOn: $model.preferences.claimUpdates)
                Toggle("Resultado de la revisión de lo que publico", isOn: $model.preferences.moderationUpdates)
            }
            .disabled(!model.preferences.enabled)

            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.subheadline)
                }
            }
        }
        .navigationTitle("Notificaciones")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Guardar") { Task { await model.save(token: session.accessToken) } }
                    .disabled(model.isSaving || model.isLoading || session.accessToken == nil)
            }
        }
        .overlay {
            if model.isLoading { ProgressView("Cargando preferencias…") }
        }
        .task { await model.load(token: session.accessToken) }
    }
}

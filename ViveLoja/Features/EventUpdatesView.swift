import SwiftUI

struct EventUpdateNotice: Decodable, Identifiable, Sendable {
    let id: String
    let title: String
    let body: String
    let slug: String
    let createdAt: Date
}

struct EventUpdatesView: View {
    @Environment(SessionStore.self) private var session
    @State private var notices: [EventUpdateNotice] = []
    @State private var loading = true
    @State private var errorMessage: String?
    var body: some View {
        List {
            if loading { ProgressView("Cargando avisos…") }
            if let errorMessage {
                Text(errorMessage)
                Button("Reintentar") { Task { await load() } }
            } else if !loading && notices.isEmpty { Text("No hay cambios en tus eventos guardados.") }
            ForEach(notices) { notice in
                NavigationLink {
                    DeepLinkDestinationView(destination: .event(slug: notice.slug))
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(notice.title).font(.headline)
                        Text(notice.body).font(.subheadline)
                        Text(notice.createdAt, style: .date).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.navigationTitle("Cambios en eventos").task { await load() }.refreshable { await load() }
    }
    @MainActor private func load() async {
        guard let token = session.accessToken else { loading = false; errorMessage = "Inicia sesión para ver tus avisos."; return }
        loading = true
        defer { loading = false }
        do { notices = try await APIClient.shared.get("/me/event-updates", bearer: token); errorMessage = nil }
        catch { errorMessage = "No pudimos cargar los avisos." }
    }
}

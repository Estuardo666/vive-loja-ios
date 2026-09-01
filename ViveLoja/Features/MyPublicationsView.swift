import Observation
import SwiftUI

@MainActor
@Observable
final class MyPublicationsViewModel {
    var venues: [MobileVenueDraft] = []
    var events: [MobileEventDraft] = []
    var posts: [MobilePostDraft] = []
    var routes: [MobileRouteDraft] = []
    var isLoading = false
    var errorMessage: String?

    var isEmpty: Bool { venues.isEmpty && events.isEmpty && posts.isEmpty && routes.isEmpty }

    func load(accessToken: String?) async {
        guard let accessToken else {
            venues = []; events = []; posts = []; routes = []; errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            async let venueTask: [MobileVenueDraft] = APIClient.shared.get("/me/venues", bearer: accessToken)
            async let eventTask: [MobileEventDraft] = APIClient.shared.get("/me/events", bearer: accessToken)
            async let postTask: [MobilePostDraft] = APIClient.shared.get("/me/posts", bearer: accessToken)
            async let routeTask: [MobileRouteDraft] = APIClient.shared.get("/me/routes", bearer: accessToken)
            (venues, events, posts, routes) = try await (venueTask, eventTask, postTask, routeTask)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar tus publicaciones."
        }
    }
}

struct MyPublicationsView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = MyPublicationsViewModel()

    var body: some View {
        List {
            if model.isLoading && model.isEmpty {
                Section { ProgressView("Cargando publicaciones…") }
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                    Button("Reintentar") {
                        Task { await model.load(accessToken: session.accessToken) }
                    }
                }
            }

            publicationSection("Locales", venues: model.venues) { venue in
                PublicationRow(title: venue.name, subtitle: venue.location, status: venue.status, date: venue.createdAt)
            }
            publicationSection("Eventos", venues: model.events) { event in
                PublicationRow(title: event.title, subtitle: event.location, status: event.status, date: event.createdAt)
            }
            publicationSection("Artículos", venues: model.posts) { post in
                PublicationRow(title: post.title, subtitle: post.category?.name, status: post.status, date: post.createdAt)
            }
            publicationSection("Rutas", venues: model.routes) { route in
                PublicationRow(title: route.title, subtitle: route.type, status: route.status, date: route.createdAt)
            }

            if !model.isLoading && model.isEmpty && model.errorMessage == nil {
                ContentUnavailableView("Aún no has publicado", systemImage: "square.and.pencil", description: Text("Tus eventos, locales, artículos y rutas aparecerán aquí."))
            }
        }
        .overlay {
            if model.isLoading && !model.isEmpty { ProgressView().controlSize(.small) }
        }
        .navigationTitle("Mis publicaciones")
        .task(id: session.user?.id) {
            guard !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
            await model.load(accessToken: session.accessToken)
        }
        .refreshable {
            await model.load(accessToken: session.accessToken)
        }
    }

    @ViewBuilder
    private func publicationSection<Item: Identifiable, Row: View>(
        _ title: String,
        venues: [Item],
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !venues.isEmpty {
            Section(title) {
                ForEach(venues) { item in row(item) }
            }
        }
    }
}

private struct PublicationRow: View {
    let title: String
    let subtitle: String?
    let status: String
    let date: Date

    private var statusLabel: String {
        switch status.uppercased() {
        case "PENDING": return "Pendiente"
        case "APPROVED": return "Aprobado"
        case "REJECTED": return "Rechazado"
        default: return status.capitalized
        }
    }

    private var dateLabel: String {
        date.formatted(.dateTime.day().month(.abbreviated).year())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(statusLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                Text(dateLabel).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), estado \(statusLabel), \(dateLabel)")
    }

    private var statusColor: Color {
        switch status.uppercased() {
        case "APPROVED": return .green
        case "REJECTED": return .red
        default: return .orange
        }
    }
}

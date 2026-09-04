import SwiftUI

@MainActor
@Observable
final class BusinessDashboardViewModel {
    private(set) var insights: MobileVenueInsights?
    private(set) var isLoading = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load(slug: String, token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            insights = try await api.get("/me/venues/\(slug)/insights", bearer: token)
            errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las métricas."
        }
    }
}

/// What the owner of a venue needs to act on, plus how the listing is doing.
///
/// The daily series comes from the timestamped view log, so it covers a rolling
/// window; the lifetime total is shown separately rather than mixed into it.
struct BusinessDashboardView: View {
    let slug: String

    @Environment(SessionStore.self) private var session
    @State private var model = BusinessDashboardViewModel()

    var body: some View {
        List {
            if let insights = model.insights {
                Section("Actividad") {
                    metric("Vistas recientes", value: "\(insights.recentViews)",
                           caption: "Últimos \(insights.retentionDays) días")
                    metric("Vistas totales", value: "\(insights.lifetimeViews)", caption: nil)
                    metric("Guardados", value: "\(insights.favorites)", caption: nil)
                    if let activity = insights.interactions {
                        metric("Nuevos guardados", value: "\(activity.saves)", caption: "Últimos \(activity.days) días")
                        metric("Cómo llegar", value: "\(activity.directions)", caption: "Clics, no visitas físicas · \(activity.days) días")
                    }
                    if let rating = insights.avgRating {
                        metric(
                            "Calificación",
                            value: String(format: "%.1f", rating),
                            caption: "\(insights.reviewCount) reseñas"
                        )
                    }
                }

                if !insights.viewSeries.isEmpty {
                    Section("Vistas por día") {
                        ViewSparkline(points: insights.viewSeries)
                            .frame(height: 90)
                            .padding(.vertical, 6)
                    }
                }

                Section("Pendientes") {
                    pending("Reseñas sin responder", count: insights.pendingReviewReplies, icon: "text.bubble")
                    pending("Preguntas sin responder", count: insights.unansweredQuestions, icon: "questionmark.circle")
                    pending("Reservas próximas", count: insights.upcomingReservations, icon: "calendar")
                }
            } else if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(model.insights?.venue.name ?? "Mi negocio")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.isLoading && model.insights == nil { ProgressView("Cargando métricas…") }
        }
        .refreshable { await model.load(slug: slug, token: session.accessToken) }
        .task { await model.load(slug: slug, token: session.accessToken) }
    }
}

private extension BusinessDashboardView {
    func metric(_ title: String, value: String, caption: String?) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let caption {
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(value).font(.title3.weight(.semibold).monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }

    func pending(_ title: String, count: Int, icon: String) -> some View {
        Label {
            HStack {
                Text(title)
                Spacer()
                Text("\(count)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(count > 0 ? VLTheme.coral : .secondary)
            }
        } icon: {
            Image(systemName: icon)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(count)")
    }
}

/// Minimal bar chart. Deliberately not Swift Charts: this is a glance, and a
/// framework dependency for six bars is not worth the binary.
private struct ViewSparkline: View {
    let points: [MobileVenueInsights.DayPoint]

    var body: some View {
        let maximum = max(points.map(\.views).max() ?? 1, 1)
        GeometryReader { proxy in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(points) { point in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(VLTheme.indigo.opacity(0.85))
                        .frame(height: max(proxy.size.height * CGFloat(point.views) / CGFloat(maximum), 2))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement()
        .accessibilityLabel(
            "Vistas por día. Máximo \(maximum) en \(points.count) días."
        )
    }
}

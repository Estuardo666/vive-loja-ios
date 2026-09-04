import SwiftUI

struct TodayCard: Codable, Identifiable, Sendable {
    let id: String
    let kind: String
    let title: String
    let slug: String
    let image: URL?
    let subtitle: String?
    let startDate: Date?
    let price: Double?
    let author: String?
    let itemCount: Int?
}

struct TodayPayload: Codable, Sendable {
    let date: String
    let timeZone: String
    let generatedAt: Date
    let events: [TodayCard]
    let openVenues: [TodayCard]
    let routes: [TodayCard]
    let collections: [TodayCard]
}

@MainActor
@Observable
final class TodayViewModel {
    var payload: TodayPayload?
    var errorMessage: String?
    var isLoading = false

    func load() async {
        guard !isLoading else { return }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            payload = TodayPayload(date: "2026-09-04", timeZone: "America/Guayaquil", generatedAt: Date(timeIntervalSince1970: 0),
                                   events: [], openVenues: [], routes: [], collections: [])
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            payload = try await APIClient.shared.get("/today")
            errorMessage = nil
        } catch {
            errorMessage = "No pudimos actualizar los planes de hoy."
        }
    }
}

struct TodayInLojaView: View {
    @State private var model = TodayViewModel()
    @Environment(DeepLinkRouter.self) private var router
    @Environment(\.scenePhase) private var scenePhase
    @ScaledMetric(relativeTo: .body) private var eventPageHeight: CGFloat = 430

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Hoy en Loja").font(.title2.bold())
            if let error = model.errorMessage {
                Text(error).font(.subheadline)
                Button("Reintentar") { Task { await model.load() } }
            } else if let data = model.payload {
                Text(data.date).font(.caption).foregroundStyle(.secondary)
                Text("En la agenda de hoy").font(.headline)
                if data.events.isEmpty {
                    Text("No hay eventos publicados para lo que queda de hoy.").foregroundStyle(.secondary)
                } else {
                    TabView {
                        ForEach(data.events) { item in visualCard(item, hero: true).padding(.bottom, 28) }
                    }
                    .tabViewStyle(.page(indexDisplayMode: data.events.count > 1 ? .always : .never))
                    .frame(height: eventPageHeight)
                    .accessibilityLabel("Eventos de hoy")
                }
                NavigationLink("Hoy, mañana y fin de semana", destination: AgendaView())
                cards("Abiertos ahora", items: data.openVenues, empty: "No hay horarios confirmados para este momento.")
                Text("Rutas turísticas de hasta tres horas").font(.headline)
                if data.routes.isEmpty {
                    Text("No hay rutas cortas publicadas todavía.").foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(data.routes) { visualCard($0, hero: false) }
                    }
                }
                cards("Colecciones de locales", items: data.collections, empty: "Pronto encontrarás selecciones de lugares con consejos locales.")
                Text("Los horarios pueden cambiar en feriados. Confirma antes de salir.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView("Buscando planes para hoy…")
            }
        }
        .accessibilityIdentifier("today-in-loja")
        .task {
            await model.load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
                if scenePhase == .active { await model.load() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.load() } }
        }
    }

    private func visualCard(_ item: TodayCard, hero: Bool) -> some View {
        Button {
            if let destination = DeepLinkRouter.destination(kind: item.kind, slug: item.slug) { router.open(destination) }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                VLAsyncImage(url: item.image, height: hero ? 220 : 130, googleVenueSlug: item.kind == "venue" ? item.slug : nil)
                    .clipped()
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title).font(hero ? .title2.bold() : .headline).lineLimit(2)
                    if let subtitle = item.subtitle { Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                    if let start = item.startDate {
                        Text("\(Self.eventTime(start)) · \(item.price.map { $0 == 0 ? "Gratis" : String(format: "$%.2f", $0) } ?? "Consultar precio")")
                            .font(.subheadline.weight(.semibold))
                    }
                }.padding([.horizontal, .bottom], 12)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain)
    }

    private func cards(_ title: String, items: [TodayCard], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if items.isEmpty {
                Text(empty).font(.subheadline).foregroundStyle(.secondary)
            } else {
                ForEach(items) { item in
                    Button {
                        if let destination = DeepLinkRouter.destination(kind: item.kind, slug: item.slug) {
                            router.open(destination)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            if let url = item.image {
                                AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: {
                                    Color.secondary.opacity(0.15)
                                }
                                .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title).font(.headline)
                                if let subtitle = item.subtitle {
                                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                }
                                if let start = item.startDate {
                                    Text(Self.eventTime(start)).font(.caption)
                                    if let price = item.price {
                                        Text(price == 0 ? "Gratis" : String(format: "$%.2f", price)).font(.caption)
                                    }
                                }
                                if let count = item.itemCount {
                                    Text("Por \(item.author ?? "Equipo Vive Loja") · \(count) locales")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").accessibilityHidden(true)
                        }
                        .padding(12).background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    static func eventTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_EC")
        formatter.timeZone = TimeZone(identifier: "America/Guayaquil")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

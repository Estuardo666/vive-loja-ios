import SwiftUI

struct WatchEventsView: View {
    @State private var events: [MobileWatchEvent] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(events) { event in
                    NavigationLink(destination: WatchEventDetailView(event: event)) {
                        WatchEventCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
                if events.isEmpty, let errorMessage {
                    ContentUnavailableView("Sin conexión", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if events.isEmpty {
                    ContentUnavailableView("No hay transmisiones", systemImage: "play.tv", description: Text("Vuelve pronto para descubrir dónde ver tus eventos favoritos."))
                }
            }
            .padding(16)
        }
        .navigationTitle("Transmisiones")
        .refreshable { await load() }
        .task { if !isUITesting { await load() } }
    }

    private func load() async {
        do { events = try await APIClient.shared.get("/watch-events") }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudieron cargar las transmisiones." }
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

private struct WatchEventCard: View {
    let event: MobileWatchEvent

    var body: some View {
        HStack(spacing: 12) {
            VLAsyncImage(url: event.image, height: 86).frame(width: 112)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                Text(event.name).font(.headline).lineLimit(2)
                Text(event.matchDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
                if let competition = event.competition { Text(competition).font(.caption).foregroundStyle(.secondary) }
                Text("\(event.venueCount ?? 0) lugares disponibles").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.secondary)
        }
        .padding(12)
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.name), \(event.matchDate.formatted(date: .abbreviated, time: .shortened))")
    }
}

struct WatchEventDetailView: View {
    let event: MobileWatchEvent
    @Environment(\.openURL) private var openURL
    @State private var detail: MobileWatchEventDetail?
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VLAsyncImage(url: detail?.image ?? event.image, height: 230)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text(detail?.name ?? event.name).font(.largeTitle.weight(.bold))
                Text((detail?.matchDate ?? event.matchDate).formatted(date: .complete, time: .shortened))
                    .font(.headline).foregroundStyle(VLTheme.indigo)
                if let description = detail?.description ?? event.description { Text(description).font(.body) }
                if let competition = detail?.competition ?? event.competition {
                    Label(competition, systemImage: "trophy.fill").font(.subheadline.weight(.semibold))
                }
                if let detail {
                    if !detail.performers.isEmpty {
                        Label(detail.performers.map(\.name).joined(separator: " · "), systemImage: "person.2.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Text("Dónde verlo").font(.title2.weight(.semibold))
                    ForEach(detail.venues) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.venue.name).font(.headline)
                            if let location = item.venue.location ?? item.venue.address { Text(location).font(.subheadline).foregroundStyle(.secondary) }
                            HStack(spacing: 10) {
                                if item.hasBigScreen { Label("Pantalla gigante", systemImage: "tv") }
                                if item.hasFreeEntry { Label("Entrada libre", systemImage: "ticket") }
                            }
                            .font(.caption.weight(.semibold)).foregroundStyle(VLTheme.coral)
                            if let phone = item.venue.phone {
                                Button("Contactar", systemImage: "message.fill") {
                                    let digits = phone.filter(\.isNumber)
                                    if let url = URL(string: "https://wa.me/\(digits)") { openURL(url) }
                                }
                                .buttonStyle(.bordered)
                            }
                            if let promotion = item.promotion, !promotion.isEmpty { Text(promotion).font(.caption).foregroundStyle(.secondary) }
                        }
                        .padding(14)
                        .vlGlass(tint: VLTheme.indigo.opacity(0.08))
                    }
                }
                if let errorMessage { Text(errorMessage).font(.footnote).foregroundStyle(.secondary) }
            }
            .padding(20)
        }
        .navigationTitle("Transmisión")
        .navigationBarTitleDisplayMode(.inline)
        .task { if !isUITesting { await load() } }
    }

    private func load() async {
        do { detail = try await APIClient.shared.get("/watch-events/\(event.slug)") }
        catch { errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar esta transmisión." }
        let _: ViewResponse? = try? await APIClient.shared.post("/views", body: ViewRequest(kind: "watchEvent", itemId: event.id))
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

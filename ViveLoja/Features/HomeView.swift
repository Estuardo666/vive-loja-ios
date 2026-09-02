import Observation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var featured: [ExploreItem] = HomeViewModel.fixtures
    var categories: [Category] = []
    var latestVenues: [ExploreVenue] = []
    var relatedEvents: [ExploreEvent] = []
    var posts: [MobilePost] = []
    var promotions: [MobilePromotion] = []
    var recommendations: MobileRecommendations?
    var isLoading = false
    var errorMessage: String?

    // Fixtures must not move with the wall clock so UI screenshots remain comparable.
    private static let fixtureEventDate = Date(timeIntervalSince1970: 1_800_000_000)

    func load(accessToken: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload: HomePayload = try await APIClient.shared.get("/home")
            let featuredVenues = payload.featuredVenues ?? payload.venues
            let featuredEvents = payload.featuredEvents ?? payload.events
            featured = featuredVenues.map(ExploreItem.venue) + featuredEvents.map(ExploreItem.event)
            categories = payload.categories
            latestVenues = payload.latestVenues ?? featuredVenues
            relatedEvents = payload.relatedEvents ?? []
            posts = payload.posts ?? []
            promotions = payload.promotions ?? []
            if let accessToken {
                recommendations = try? await APIClient.shared.get("/me/recommendations", bearer: accessToken)
            } else {
                recommendations = nil
            }
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }

    static let fixtures: [ExploreItem] = [
        .venue(ExploreVenue(id: "fixture-venue-1", name: "Café Loja", slug: "cafe-loja", description: "Café de altura y ambiente acogedor.", image: URL(string: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800"), location: "Centro histórico", address: "Calle Bolívar, Loja", lat: -4.0079, lng: -79.2045, featured: true, phone: nil, website: nil, priceRange: "$$", avgRating: 4.8, reviewCount: 32, verified: true, categories: [])),
        .event(ExploreEvent(id: "fixture-event-1", title: "Música en vivo", slug: "musica-en-vivo", description: "Una noche para disfrutar artistas locales.", image: URL(string: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800"), startDate: HomeViewModel.fixtureEventDate, endDate: nil, location: "Teatro Benjamín Carrión", address: "Loja", lat: -3.9931, lng: -79.2042, featured: true, price: 0, avgRating: nil, reviewCount: 0, categories: []))
    ]
}

struct HomeView: View {
    @State private var model = HomeViewModel()
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    VStack(alignment: .leading, spacing: 14) {
                        VLSectionHeader(title: "Destacados", action: nil)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(model.featured) { item in
                                    NavigationLink(destination: ItemDetailView(item: item)) {
                                        VLItemCard(item: item).frame(width: 265)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    if !model.latestVenues.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            VLSectionHeader(title: "Últimos locales", action: nil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(model.latestVenues) { venue in
                                        NavigationLink(destination: ItemDetailView(item: .venue(venue))) {
                                            VLItemCard(item: .venue(venue)).frame(width: 265)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if let recommendations = model.recommendations, !recommendations.relatedVenues.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            VLSectionHeader(title: "Recomendado para ti", action: nil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(recommendations.relatedVenues) { venue in
                                        NavigationLink(destination: ItemDetailView(item: .venue(venue))) {
                                            VLItemCard(item: .venue(venue)).frame(width: 265)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if !model.relatedEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            VLSectionHeader(title: "Eventos relacionados", action: nil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(model.relatedEvents) { event in
                                        NavigationLink(destination: ItemDetailView(item: .event(event))) {
                                            VLItemCard(item: .event(event)).frame(width: 265)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    if !model.posts.isEmpty || !model.promotions.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            VLSectionHeader(title: "Actualidad en Loja", action: nil)
                            if !model.posts.isEmpty {
                                NavigationLink(destination: ContentHubView()) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "text.book.closed.fill")
                                            .font(.title2)
                                            .foregroundStyle(VLTheme.indigo)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(model.posts[0].title).font(.headline).lineLimit(2)
                                            Text("Ver historias, promociones y rutas")
                                                .font(.subheadline).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(14)
                                    .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Abrir actualidad de Loja")
                            }
                            VLGlassEffectContainer(spacing: 12) {
                                ForEach(model.promotions.prefix(3)) { promotion in
                                    HStack(spacing: 12) {
                                        Image(systemName: "tag.fill")
                                            .font(.title3)
                                            .foregroundStyle(VLTheme.coral)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(promotion.title).font(.headline).lineLimit(2)
                                            Text(promotion.venue.name).font(.caption.weight(.semibold)).foregroundStyle(VLTheme.coral)
                                        }
                                        Spacer()
                                    }
                                    .padding(14)
                                    .vlGlass(tint: VLTheme.coral.opacity(0.1))
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(promotion.title), \(promotion.venue.name)")
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        VLSectionHeader(title: "Explora Loja", action: nil)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if model.categories.isEmpty {
                                category("🍽️", "Restaurantes", VLTheme.coral)
                                category("🎵", "Eventos", VLTheme.indigo)
                                category("☕", "Cafeterías", .brown)
                                category("🌿", "Rutas", VLTheme.emerald)
                            } else {
                                ForEach(model.categories.prefix(6), id: \.id) { value in
                                    category(value.icon ?? "✨", value.name, color(for: value.color))
                                }
                            }
                        }
                    }
                    NavigationLink(destination: ContentHubView()) {
                        Label("Todo lo que pasa en Loja", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.indigo)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Vive Loja")
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task { if !isUITesting { await model.load(accessToken: session.accessToken) } }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loja está viva")
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .tracking(-1.2)
                .minimumScaleFactor(0.75)
            Text("Descubre eventos, locales y planes cerca de ti.").font(.title3).foregroundStyle(.secondary)
            NavigationLink(destination: ExploreView()) {
                Label("Explorar el mapa", systemImage: "map.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(VLTheme.indigo, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20).vlGlass(tint: VLTheme.indigo.opacity(0.12), radius: 26)
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    private func category(_ emoji: String, _ title: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(emoji).font(.title); Text(title).font(.headline) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.2)) }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Explorar categoría")
    }

    private func color(for value: String?) -> Color {
        guard let value else { return VLTheme.indigo }
        let lowercased = value.lowercased()
        if lowercased.contains("coral") || lowercased.contains("red") { return VLTheme.coral }
        if lowercased.contains("green") || lowercased.contains("emerald") { return VLTheme.emerald }
        return VLTheme.indigo
    }
}

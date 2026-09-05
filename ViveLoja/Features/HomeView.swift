import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class HomeViewModel {
    /// Server-driven composition. Empty means the backend did not send one, and
    /// the view falls back to the sections built from the legacy payload keys.
    var sections: [HomeSection] = []
    var featured: [ExploreItem] = HomeViewModel.fixtures
    var categories: [Category] = []
    var latestVenues: [ExploreVenue] = []
    var relatedEvents: [ExploreEvent] = []
    var popularNow: [ExploreVenue] = []
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
            sections = (payload.sections ?? []).filter(\.isRenderable)
            let featuredVenues = payload.featuredVenues ?? payload.venues
            let featuredEvents = payload.featuredEvents ?? payload.events
            featured = featuredVenues.map(ExploreItem.venue) + featuredEvents.map(ExploreItem.event)
            categories = payload.categories
            latestVenues = payload.latestVenues ?? featuredVenues
            relatedEvents = payload.relatedEvents ?? []
            popularNow = payload.popularNow ?? []
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
        .venue(ExploreVenue(id: "fixture-venue-1", name: "Café Loja", slug: "cafe-loja", description: "Café de altura y ambiente acogedor.", image: URL(string: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800"), location: "Centro histórico", address: "Calle Bolívar, Loja", lat: -4.0079, lng: -79.2045, featured: true, phone: nil, website: nil, priceRange: "$$", avgRating: 4.8, reviewCount: 32, verified: true, categories: [], openState: nil)),
        .event(ExploreEvent(id: "fixture-event-1", title: "Música en vivo", slug: "musica-en-vivo", description: "Una noche para disfrutar artistas locales.", image: URL(string: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800"), startDate: HomeViewModel.fixtureEventDate, endDate: nil, location: "Teatro Benjamín Carrión", address: "Loja", lat: -3.9931, lng: -79.2042, featured: true, price: 0, avgRating: nil, reviewCount: 0, categories: []))
    ]
}

struct HomeView: View {
    @State private var model = HomeViewModel()
    @Environment(SessionStore.self) private var session
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var deepLinkRouter = deepLinkRouter
        return NavigationStack(path: $deepLinkRouter.homePath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    searchEntry
                    if model.sections.isEmpty {
                        // No configured composition (older backend, or the very
                        // first run before seeding): keep the previous screen.
                        legacyHome
                    } else {
                        ForEach(model.sections) { section in
                            if section.type == .todayInLoja {
                                if showsTodayInLoja { TodayInLojaView() }
                            } else {
                                HomeSectionView(section: section)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .overlay(alignment: .bottom) { mapButton }
            .vlScreen()
            .navigationTitle("Vive Loja")
            .navigationDestination(for: DeepLinkRouter.Destination.self) { DeepLinkDestinationView(destination: $0) }
            .toolbarTitleDisplayMode(.inlineLarge)
            .refreshable { await model.load(accessToken: session.accessToken) }
            .task { if !isUITesting { await model.load(accessToken: session.accessToken) } }
        }
    }

    /// Entry point to search: the home only shows the field, the typing happens
    /// on Explorar, which already owns the query, the filters and the map.
    private var searchEntry: some View {
        NavigationLink(destination: ExploreView()) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                Text("Descubre Loja").foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "slider.horizontal.3").foregroundStyle(.secondary)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(VLTheme.surface, in: Capsule())
            .overlay { Capsule().stroke(VLTheme.outline) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Buscar en Loja")
    }

    private var mapButton: some View {
        NavigationLink(destination: ExploreView()) {
            Label("Mapa", systemImage: "map")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .vlGlass(tint: VLTheme.indigo.opacity(0.18), radius: 24)
        .padding(.bottom, 12)
        .accessibilityLabel("Abrir el mapa")
    }

    @ViewBuilder private var legacyHome: some View {
                    hero
                    if showsTodayInLoja { TodayInLojaView() }
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
                    if !model.popularNow.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            VLSectionHeader(title: "Popular ahora", action: nil)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 14) {
                                    ForEach(model.popularNow) { venue in
                                        NavigationLink(destination: ItemDetailView(item: .venue(venue))) {
                                            VLItemCard(item: .venue(venue)).frame(width: 265)
                                        }
                                        .buttonStyle(.plain)
                                    }
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
                        LazyVGrid(columns: categoryColumns, spacing: 12) {
                            if model.categories.isEmpty {
                                category(systemImage: "fork.knife", title: "Restaurantes", color: VLTheme.coral)
                                category(systemImage: "music.note", title: "Eventos", color: VLTheme.indigo)
                                category(systemImage: "cup.and.saucer.fill", title: "Cafeterías", color: .brown)
                                category(systemImage: "leaf.fill", title: "Rutas", color: VLTheme.emerald)
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

    /// Screenshot runs skip the live "Hoy en Loja" block unless the dedicated
    /// fixture argument asks for it.
    private var showsTodayInLoja: Bool {
        !ProcessInfo.processInfo.arguments.contains("-uiTesting")
            || ProcessInfo.processInfo.arguments.contains("-uiTesting-today")
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    private var categoryColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible()),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
    }

    private func category(_ emoji: String, _ title: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(emoji).font(.title).accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(uiColor: .label))
                .fixedSize(horizontal: false, vertical: true)
        }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color, lineWidth: 2) }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Explorar categoría")
    }

    private func category(systemImage: String, title: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundStyle(Color(uiColor: .label))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color, lineWidth: 2) }
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

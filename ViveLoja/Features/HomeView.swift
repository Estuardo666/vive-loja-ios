import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class HomeViewModel {
    /// Server-driven composition. Empty means the backend did not send one, and
    /// the view falls back to the sections built from the legacy payload keys.
    var sections: [HomeSection] = []
    var featured: [ExploreItem] = []
    var categories: [Category] = []
    var latestVenues: [ExploreVenue] = []
    var relatedEvents: [ExploreEvent] = []
    var popularNow: [ExploreVenue] = []
    var posts: [MobilePost] = []
    var promotions: [MobilePromotion] = []
    var recommendations: MobileRecommendations?
    var isLoading = false
    var errorMessage: String?
    var hasLoaded = false
    var initialLoadFinished = false
    let today = TodayViewModel()

    init() {
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            featured = Self.fixtures
            hasLoaded = true
            initialLoadFinished = true
        }
    }

    // Fixtures must not move with the wall clock so UI screenshots remain comparable.
    private static let fixtureEventDate = Date(timeIntervalSince1970: 1_800_000_000)

    func load(accessToken: String? = nil) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; initialLoadFinished = true }

        // Everything the first screen needs leaves at once. `/home` used to be
        // awaited before `/today` was even requested, which put two round trips
        // end to end on the critical path of every launch.
        let request = Task { () throws -> HomePayload in try await APIClient.shared.get("/home") }
        async let personal = loadRecommendations(accessToken: accessToken)
        // Speculative: nearly every composition includes the module, and the
        // payload is small. Worth one redundant GET to keep it off the tail of
        // the home request.
        async let todayPrefetch: Void = today.load()
        Task { await today.restoreSnapshot() }

        // Paints the last good response while the live one is in flight, so a
        // warm launch reaches content without ever showing a spinner.
        await restoreSnapshot()

        do {
            let payload = try await request.value

            // Publish the public home payload as soon as it arrives. Today and
            // recommendations are secondary sections; waiting for either one
            // kept the cards behind an unrelated request on slow networks.
            apply(payload)
            hasLoaded = true
            initialLoadFinished = true
            prefetchVisibleDetails()

            // The session can finish restoring while the public home request
            // is still in flight. Do not erase recommendations loaded by that
            // concurrent session task with this anonymous request's nil value.
            let nextRecommendations = await personal
            if let nextRecommendations {
                recommendations = nextRecommendations
            } else if accessToken != nil {
                recommendations = nil
            }

            // Keep the home snapshot write off the main actor. It is written
            // independently from the first paint and is only a warm-launch
            // optimisation, never a reason to delay content.
            let snapshot = payload
            Task.detached(priority: .utility) {
                await SnapshotStore.shared.write(snapshot, for: SnapshotStore.Key.home)
            }
            await todayPrefetch
        } catch {
            await todayPrefetch
            _ = await personal
            // A snapshot already on screen is better than an error panel.
            guard !hasLoaded else { return }
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No pudimos cargar el inicio. Inténtalo de nuevo."
        }
    }

    /// Publishes a payload, whether it came from the network or from disk.
    private func apply(_ payload: HomePayload) {
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
    }

    /// Best-effort first paint from the last successful launch. Never overwrites
    /// live data: if the network already answered, this does nothing.
    private func restoreSnapshot() async {
        guard !hasLoaded, !ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }
        guard let cached: HomePayload = await SnapshotStore.shared.read(SnapshotStore.Key.home) else { return }
        guard !hasLoaded else { return }
        apply(cached)
        hasLoaded = true
        initialLoadFinished = true
        prefetchVisibleDetails()
    }

    /// Warm only the first visible venue/event cards; details remain first-party
    /// in the API client's short-lived in-memory cache, never on disk.
    private func prefetchVisibleDetails() {
        let cards = sections.flatMap { $0.items.prefix(2) }
        var seen = Set<String>()
        let unique = cards.compactMap { card -> (HomeItem.Kind, String)? in
            guard card.kind == .venue || card.kind == .event,
                  seen.insert(card.id).inserted else { return nil }
            return (card.kind, card.slug)
        }
        let targets = Array(unique.filter { $0.0 == .venue }.prefix(2))
            + Array(unique.filter { $0.0 == .event }.prefix(2))
        Task(priority: .utility) {
            await withTaskGroup(of: Void.self) { group in
                for (kind, slug) in targets {
                    group.addTask {
                        switch kind {
                        case .venue:
                            let _: VenueDetail? = try? await APIClient.shared.get("/venues/\(slug)")
                        case .event:
                            let _: EventDetail? = try? await APIClient.shared.get("/events/\(slug)")
                        default: break
                        }
                    }
                }
            }
        }
    }

    private func loadRecommendations(accessToken: String?) async -> MobileRecommendations? {
        guard let accessToken else { return nil }
        return try? await APIClient.shared.get("/me/recommendations", bearer: accessToken)
    }

    func reloadRecommendations(accessToken: String?) async {
        recommendations = await loadRecommendations(accessToken: accessToken)
    }

    static let fixtures: [ExploreItem] = [
        .venue(ExploreVenue(id: "fixture-venue-1", name: "Café Loja", slug: "cafe-loja", description: "Café de altura y ambiente acogedor.", image: URL(string: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800"), location: "Centro histórico", address: "Calle Bolívar, Loja", lat: -4.0079, lng: -79.2045, featured: true, phone: nil, website: nil, priceRange: "$$", avgRating: 4.8, reviewCount: 32, verified: true, categories: [], openState: nil)),
        .event(ExploreEvent(id: "fixture-event-1", title: "Música en vivo", slug: "musica-en-vivo", description: "Una noche para disfrutar artistas locales.", image: URL(string: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800"), startDate: HomeViewModel.fixtureEventDate, endDate: nil, location: "Teatro Benjamín Carrión", address: "Loja", lat: -3.9931, lng: -79.2042, featured: true, price: 0, avgRating: nil, reviewCount: 0, categories: []))
    ]
}

struct HomeView: View {
    let model: HomeViewModel
    @Environment(SessionStore.self) private var session
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var deepLinkRouter = deepLinkRouter
        return NavigationStack(path: $deepLinkRouter.homePath) {
            ScrollView {
                // No horizontal padding here on purpose: each section applies
                // its own, so a carousel can scroll to the edge of the screen
                // instead of being clipped by the page margin.
                VStack(alignment: .leading, spacing: 28) {
                    if model.isLoading && !model.initialLoadFinished {
                        ProgressView("Cargando Loja…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 64)
                    } else if !model.hasLoaded {
                        ContentUnavailableView {
                            Label("No pudimos cargar el inicio", systemImage: "wifi.exclamationmark")
                        } description: {
                            Text(model.errorMessage ?? "Comprueba tu conexión e inténtalo de nuevo.")
                        } actions: {
                            Button("Reintentar") { Task { await model.load(accessToken: session.accessToken) } }
                                .disabled(model.isLoading)
                            if model.isLoading { ProgressView() }
                        }
                    } else {
                        if let recommendations = model.recommendations, recommendations.hasDiscoverySignals {
                            personalizedHome(recommendations)
                        }
                        if model.sections.isEmpty {
                            // No configured composition (older backend, or the very
                            // first run before seeding): keep the previous screen.
                            legacyHome
                        } else {
                            ForEach(model.sections) { section in
                                if section.type == .todayInLoja {
                                    if showsTodayInLoja {
                                        TodayInLojaView(model: model.today).padding(.horizontal, homeSectionInset)
                                    }
                                } else {
                                    HomeSectionView(section: section)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 12).padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            // Sticky: the field stays reachable however far down the page goes.
            .safeAreaInset(edge: .top, spacing: 0) { searchBar }
            .overlay(alignment: .bottom) { mapButton }
            .vlScreen()
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: DeepLinkRouter.Destination.self) { DeepLinkDestinationView(destination: $0) }
            .toolbarTitleDisplayMode(.inline)
            .refreshable { await model.load(accessToken: session.accessToken) }
            .onReceive(NotificationCenter.default.publisher(for: .discoveryPreferencesChanged)) { _ in
                Task { await model.reloadRecommendations(accessToken: session.accessToken) }
            }
        }
    }

    private func personalizedHome(_ recommendations: MobileRecommendations) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TU CARTELERA").font(.caption2.weight(.bold)).tracking(1.2).foregroundStyle(VLTheme.indigo)
                    Text("Elegido para ti").font(.title2.weight(.semibold))
                    Text("Tus preferencias deciden qué aparece primero.").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                NavigationLink(destination: InterestsView()) {
                    Image(systemName: "slider.horizontal.3")
                        .frame(width: 44, height: 44)
                        .background(VLTheme.surface, in: Circle())
                        .overlay { Circle().stroke(VLTheme.outline) }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar preferencias del inicio")
            }

            if !recommendations.relatedEvents.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Próximos planes").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(recommendations.relatedEvents.prefix(4)) { event in
                                NavigationLink(destination: ItemDetailView(item: .event(event))) {
                                    VLItemCard(item: .event(event))
                                        .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            if !recommendations.relatedVenues.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lugares que encajan contigo").font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 14) {
                            ForEach(recommendations.relatedVenues.prefix(4)) { venue in
                                NavigationLink(destination: ItemDetailView(item: .venue(venue))) {
                                    VLItemCard(item: .venue(venue))
                                        .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, homeSectionInset)
    }

    /// Entry point to search: the home only shows the field, the typing happens
    /// on Explorar, which already owns the query, the filters and the map.
    private var searchEntry: some View {
        NavigationLink(destination: ExploreView(initialShowMap: false)) {
            // Explicit palette colours rather than `.secondary`: the bar behind
            // this field is a material, and SwiftUI vibrancy-blends
            // hierarchical styles over materials. That washed the placeholder
            // out to 3.32:1 on the capsule even though `subtext` is 7.58:1.
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(VLTheme.subtext)
                Text("Descubre Loja").foregroundStyle(VLTheme.subtext)
                Spacer()
                Image(systemName: "slider.horizontal.3").foregroundStyle(VLTheme.subtext)
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
        NavigationLink(destination: ExploreView(initialShowMap: true)) {
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

    private var searchBar: some View {
        HStack(spacing: 12) {
            VLBrandLogo(side: 42)
            searchEntry
        }
            .padding(.horizontal, homeSectionInset)
            .padding(.vertical, 10)
            .background(.bar)
    }

    @ViewBuilder private var legacyHome: some View {
        // Keeps the page margin the fixed sections were written for; the
        // configured ones apply their own.
        VStack(alignment: .leading, spacing: 28) {
                    if showsTodayInLoja { TodayInLojaView(model: model.today) }
                    VStack(alignment: .leading, spacing: 14) {
                        VLSectionHeader(title: "Destacados", action: nil)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(model.featured) { item in
                                    NavigationLink(destination: ItemDetailView(item: item)) {
                                        VLItemCard(item: item)
                                            .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
                                    }
                                    .buttonStyle(.plain)
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
                                            VLItemCard(item: .venue(venue))
                                                .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
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
                                            VLItemCard(item: .venue(venue))
                                                .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
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
                                            VLItemCard(item: .event(event))
                                                .containerRelativeFrame(.horizontal, count: dynamicTypeSize.isAccessibilitySize ? 1 : 2, span: 1, spacing: 14)
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
                                    category(systemImage: categorySystemImage(value), title: value.name, color: color(for: value.color))
                                }
                            }
                        }
                    }
                    NavigationLink(destination: ContentHubView()) {
                        Label("Todo lo que pasa en Loja", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundStyle(VLTheme.background)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(VLTheme.indigo, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
        }
        .padding(.horizontal, homeSectionInset)
    }

    /// Screenshot runs skip the live "Hoy en Loja" block unless the dedicated
    /// fixture argument asks for it.
    private var showsTodayInLoja: Bool {
        !ProcessInfo.processInfo.arguments.contains("-uiTesting")
            || ProcessInfo.processInfo.arguments.contains("-uiTesting-today")
    }

    private var categoryColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible()),
            count: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        )
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

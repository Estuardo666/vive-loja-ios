import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ExploreViewModel {
    var query = ""
    var type = "all"
    var minRating: Double?
    var openNow = false
    var verified = false
    var hasPromotions = false
    var hasUpcomingEvents = false
    var priceRange: String?
    var services: [String] = []
    var foodTypes: [String] = []
    var eventDatePreset: String?
    var eventPrice: String?
    var eventMaxPrice: Double?
    var eventType: String?
    var categorySlugs: [String] = []
    var categories: [Category] = []
    var items: [ExploreItem] = HomeViewModel.fixtures
    var isLoading = false
    var errorMessage: String?

    func search(center: CLLocationCoordinate2D? = nil, radiusMeters: CLLocationDistance? = nil) async {
        isLoading = true
        defer { isLoading = false }
        var queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: type), URLQueryItem(name: "take", value: "60")]
        if let minRating { queryItems.append(URLQueryItem(name: "minRating", value: String(minRating))) }
        if openNow { queryItems.append(URLQueryItem(name: "openNow", value: "true")) }
        if verified { queryItems.append(URLQueryItem(name: "verified", value: "true")) }
        if hasPromotions { queryItems.append(URLQueryItem(name: "hasPromotions", value: "true")) }
        if hasUpcomingEvents { queryItems.append(URLQueryItem(name: "hasUpcomingEvents", value: "true")) }
        if let priceRange { queryItems.append(URLQueryItem(name: "priceRange", value: priceRange)) }
        if !services.isEmpty { queryItems.append(URLQueryItem(name: "services", value: services.joined(separator: ","))) }
        if !foodTypes.isEmpty { queryItems.append(URLQueryItem(name: "foodTypes", value: foodTypes.joined(separator: ","))) }
        if let eventDatePreset { queryItems.append(URLQueryItem(name: "eventDatePreset", value: eventDatePreset)) }
        if let eventPrice { queryItems.append(URLQueryItem(name: "eventPrice", value: eventPrice)) }
        if let eventMaxPrice { queryItems.append(URLQueryItem(name: "eventMaxPrice", value: String(eventMaxPrice))) }
        if let eventType { queryItems.append(URLQueryItem(name: "eventType", value: eventType)) }
        if !categorySlugs.isEmpty { queryItems.append(URLQueryItem(name: "category", value: categorySlugs.joined(separator: ","))) }
        if let center, let radiusMeters {
            queryItems += [
                URLQueryItem(name: "lat", value: String(center.latitude)),
                URLQueryItem(name: "lng", value: String(center.longitude)),
                URLQueryItem(name: "radius", value: String(radiusMeters)),
            ]
        }
        queryItems.removeAll { $0.value?.isEmpty == true }
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            items = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        if let payload: HomePayload = try? await APIClient.shared.get("/home") { categories = payload.categories }
    }

    var activeFilterCount: Int {
        [minRating != nil, openNow, verified, hasPromotions, hasUpcomingEvents, priceRange != nil, !categorySlugs.isEmpty,
         !services.isEmpty, !foodTypes.isEmpty, eventDatePreset != nil, eventPrice != nil,
         eventMaxPrice != nil, eventType != nil].filter { $0 }.count
    }

    func resetFilters() {
        minRating = nil; openNow = false; verified = false; hasPromotions = false; hasUpcomingEvents = false
        priceRange = nil; services = []; foodTypes = []; eventDatePreset = nil; eventPrice = nil; categorySlugs = []
        eventMaxPrice = nil; eventType = nil
    }
}

struct ExploreView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = ExploreViewModel()
    @State private var mapRegion = ExploreView.region(around: CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422), radiusMeters: 1_000)
    /// Anchor of the search area. Kept separate from the live map region so
    /// panning does not drag (and redraw) the radius overlay.
    @State private var searchCenter = CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422)
    @State private var selectedMapItemID: String?
    @State private var radiusMeters: CLLocationDistance = 1_000
    @State private var showMap = true
    @State private var showFilters = false
    @State private var location = LocationService()
    @Environment(SessionStore.self) private var session
    @State private var useNearMe = false
    @State private var routeService = RouteService()
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showRouteSteps = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Picker("Tipo", selection: $model.type) {
                    Text("Todo").tag("all"); Text("Locales").tag("venues"); Text("Eventos").tag("events")
                }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 6)
                if showMap { map } else { list }
            }
            .navigationTitle("Explorar")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilters = true
                    } label: {
                        Label(
                            model.activeFilterCount > 0 ? "Filtros \(model.activeFilterCount)" : "Filtros",
                            systemImage: model.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityLabel("Filtros de exploración")
                }
                ToolbarItem(placement: .topBarTrailing) { Button {
                    if reduceMotion { showMap.toggle() } else { withAnimation(.snappy) { showMap.toggle() } }
                } label: { Image(systemName: showMap ? "list.bullet" : "map") }.accessibilityLabel(showMap ? "Ver lista" : "Ver mapa") }
            }
            .task {
                guard !isUITesting else { return }
                // Explore always opens on the map, so ask for the user's position
                // up front instead of waiting for them to press the crosshair.
                if !useNearMe { useNearMe = true; location.requestCurrentLocation() }
                await model.search()
                await model.loadCategories()
            }
            .onChange(of: model.type) { _, _ in
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: location.coordinate?.lat) { _, _ in
                guard useNearMe, let coordinate = location.coordinate else { return }
                let center = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
                searchCenter = center
                withAnimation(reduceMotion ? nil : Animation.snappy) { mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters) }
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: location.location?.timestamp) { _, _ in
                guard let fix = location.location, routeService.isGuiding else { return }
                Task { await routeService.update(with: fix) }
            }
            .onChange(of: radiusMeters) { _, _ in
                let center = searchCenter
                withAnimation(reduceMotion ? nil : Animation.snappy) { mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters) }
                guard showMap || useNearMe, !isUITesting else { return }
                Task { await runSearch() }
            }
            .sheet(isPresented: Binding(get: { selectedMapItemID != nil }, set: { if !$0 { selectedMapItemID = nil } })) {
                if let selectedMapItemID, let item = model.items.first(where: { $0.id == selectedMapItemID }) {
                    MapItemPeekView(item: item) {
                        self.selectedMapItemID = nil
                        Task { await startRoute(to: item) }
                    }
                        .presentationDetents([.height(MapItemPeekView.height(for: item))])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showRouteSteps) {
                RouteStepsSheet(service: routeService).presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFilters) {
                ExploreFiltersView(model: model) {
                    if !isUITesting {
                        Task { await runSearch() }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    /// Frames the requested radius with margin so the circle is fully visible.
    static func region(around center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, latitudinalMeters: radiusMeters * 2.6, longitudinalMeters: radiusMeters * 2.6)
    }

    private func runSearch() async {
        if useNearMe, let coordinate = location.coordinate {
            await model.search(center: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng), radiusMeters: radiusMeters)
        } else if showMap {
            await model.search(center: mapRegion.center, radiusMeters: radiusMeters)
        } else {
            await model.search()
        }
    }

    private func startRoute(to item: ExploreItem) async {
        guard let target = item.coordinate else { return }
        guard let origin = location.location?.coordinate ?? location.coordinate.map({ CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }) else {
            location.requestCurrentLocation()
            routeService.stop()
            return
        }
        location.startTracking()
        await routeService.start(
            to: RouteService.Destination(name: item.title, latitude: target.lat, longitude: target.lng),
            from: origin,
            mode: routeService.mode
        )
    }

    private func changeRouteMode(_ mode: RouteService.Mode) async {
        guard let origin = location.location?.coordinate else { return }
        await routeService.changeMode(mode, from: origin)
    }

    private func stopRoute() {
        routeService.stop()
        location.stopTracking()
    }

    private var mapStylePicker: some View {
        Menu {
            Picker("Estilo del mapa", selection: $mapStyle) {
                ForEach(MapStyleOption.allCases) { style in
                    Label(style.label, systemImage: style.symbol).tag(style)
                }
            }
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.headline)
                .frame(width: 28, height: 22)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .vlGlass(radius: 14)
        .accessibilityLabel("Estilo del mapa")
    }

    private var radiusPicker: some View {
        Picker("Radio", selection: $radiusMeters) {
            Text("100 m").tag(CLLocationDistance(100))
            Text("500 m").tag(CLLocationDistance(500))
            Text("1 km").tag(CLLocationDistance(1_000))
            Text("2 km").tag(CLLocationDistance(2_000))
            Text("3 km").tag(CLLocationDistance(3_000))
            Text("5 km").tag(CLLocationDistance(5_000))
        }
        .accessibilityLabel("Radio de búsqueda")
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Lugares, eventos, direcciones…", text: $model.query)
                .submitLabel(.search).onSubmit { Task { await model.search() } }
            if !model.query.isEmpty { Button { model.query = ""; Task { await model.search() } } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) } }
        }
        .padding(12).vlGlass(radius: 16).padding(.horizontal, 16)
        .accessibilityIdentifier("explore-search")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 24) }
                ForEach(model.items) { item in NavigationLink(destination: ItemDetailView(item: item)) { VLItemCard(item: item) }.buttonStyle(.plain) }
                if let error = model.errorMessage { ContentUnavailableView("No se pudo actualizar", systemImage: "wifi.exclamationmark", description: Text(error)) }
            }
            .padding(16)
        }
    }

    private var map: some View {
        ZStack(alignment: .topTrailing) {
            ClusteredMapView(
                items: model.items,
                region: $mapRegion,
                selectedItemID: $selectedMapItemID,
                radiusMeters: radiusMeters,
                circleCenter: searchCenter,
                userPhotoURL: session.avatarURL,
                mapStyle: mapStyle,
                route: routeService.route,
                isGuiding: routeService.isGuiding,
                onRegionChange: { newRegion in
                    guard showMap, !useNearMe, !isUITesting else { return }
                    searchCenter = newRegion.center
                    Task { await model.search(center: newRegion.center, radiusMeters: radiusMeters) }
                }
            )
                .ignoresSafeArea(edges: .bottom)
            HStack(spacing: 8) {
                Button {
                    useNearMe.toggle()
                    if useNearMe {
                        location.requestCurrentLocation()
                    } else {
                        searchCenter = mapRegion.center
                        Task { await runSearch() }
                    }
                } label: {
                    Image(systemName: useNearMe ? "location.fill" : "location.viewfinder")
                        .font(.headline)
                        .foregroundStyle(useNearMe ? Color.white : Color.primary)
                        .frame(width: 28, height: 22)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                }
                .vlGlass(tint: useNearMe ? VLTheme.indigo : nil, radius: 14)
                .accessibilityIdentifier("explore-near-me")
                .accessibilityLabel("Cerca de mí")
                .accessibilityAddTraits(useNearMe ? [.isSelected] : [])
                mapStylePicker
                radiusPicker
                    .pickerStyle(.menu)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .vlGlass(tint: VLTheme.indigo, radius: 14)
            }
            .padding(16)
            .overlay(alignment: .bottomTrailing) {
                if location.isRequesting { ProgressView().controlSize(.small).padding(.trailing, 20) }
            }
            if routeService.destination != nil {
                VStack { Spacer(); RouteGuidanceBanner(
                    service: routeService,
                    onChangeMode: { mode in Task { await changeRouteMode(mode) } },
                    onShowSteps: { showRouteSteps = true },
                    onStop: { stopRoute() }
                ).padding(.bottom, 12) }
            }
            if useNearMe, let message = location.errorMessage {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .vlGlass(tint: VLTheme.coral, radius: 12)
                    .padding(.horizontal, 16)
                    .padding(.top, 62)
            }
        }
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

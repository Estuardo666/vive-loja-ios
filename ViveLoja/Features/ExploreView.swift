import CoreLocation
import MapKit
import SwiftUI

struct ExploreView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionStore.self) private var session
    @State private var model = ExploreViewModel()
    @State private var mapRegion = ExploreView.region(around: CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422), radiusMeters: 1_000)
    /// Anchor of the search area. Kept separate from the live map region so
    /// panning does not drag the ring away from what was searched.
    @State private var searchCenter = CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422)
    @State private var selectedMapItemID: String?
    @State private var radiusMeters: CLLocationDistance = 1_000
    @State private var showMap = true
    @State private var showFilters = false
    @State private var location = LocationService()
    @State private var useNearMe = false
    @State private var routeService = RouteService()
    @State private var mapStyle: MapStyleOption = .standard
    @State private var showRouteSteps = false
    @State private var projection = MapProjection()
    @State private var headerHeight: CGFloat = 0

    private static let radiusSteps: [CLLocationDistance] = [100, 500, 1_000, 2_000, 3_000, 5_000]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                content
                header
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
                if routeService.destination != nil {
                    VStack {
                        Spacer()
                        RouteGuidanceBanner(
                            service: routeService,
                            onChangeMode: { mode in Task { await changeRouteMode(mode) } },
                            onShowSteps: { showRouteSteps = true },
                            onStop: { stopRoute() }
                        )
                        .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("Explorar")
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: {
                        Label(
                            model.activeFilterCount > 0 ? "Filtros \(model.activeFilterCount)" : "Filtros",
                            systemImage: model.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle"
                        )
                    }
                    .accessibilityLabel("Filtros de exploración")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if reduceMotion { showMap.toggle() } else { withAnimation(.snappy) { showMap.toggle() } }
                    } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                    .accessibilityLabel(showMap ? "Ver lista" : "Ver mapa")
                }
            }
            .task {
                guard !isUITesting else { return }
                // Explore opens on the map, so ask for the position up front
                // instead of waiting for the crosshair to be pressed.
                if !useNearMe { useNearMe = true; location.requestCurrentLocation() }
                await model.search()
                await model.loadCategories()
            }
            .onChange(of: model.type) { _, _ in
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: model.categorySlugs) { _, _ in
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: location.coordinate?.lat) { _, _ in
                guard useNearMe, let coordinate = location.coordinate else { return }
                let center = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
                searchCenter = center
                withAnimation(reduceMotion ? nil : Animation.snappy) {
                    mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters)
                }
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: location.location?.timestamp) { _, _ in
                guard let fix = location.location, routeService.isGuiding else { return }
                Task { await routeService.update(with: fix) }
            }
            .onChange(of: radiusMeters) { _, _ in
                withAnimation(reduceMotion ? nil : Animation.snappy) {
                    mapRegion = ExploreView.region(around: searchCenter, radiusMeters: radiusMeters)
                }
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
                    if !isUITesting { Task { await runSearch() } }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Layout

    @ViewBuilder
    private var content: some View {
        if showMap {
            map.ignoresSafeArea(edges: .bottom)
        } else {
            list.safeAreaPadding(.top, headerHeight)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            searchBar
            Picker("Tipo", selection: $model.type) {
                Text("Todo").tag("all"); Text("Locales").tag("venues"); Text("Eventos").tag("events")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            controlRow
        }
        .padding(.top, 6)
        .padding(.bottom, 14)
        .vlProgressiveHeaderBackground()
    }

    /// Quick category chips on the left, map controls on the right.
    ///
    /// The chips used to be `.scrollClipDisabled()`, which let them keep
    /// drawing past their own bounds — so scrolling slid them underneath the
    /// glass map controls instead of stopping beside them. They clip now, and
    /// the controls hold their width: `mapControls` is built from fixed 34pt
    /// frames, so the priority keeps the scroll view from squeezing it out of
    /// the row when there are a lot of categories.
    private var controlRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(model.quickCategories, id: \.id) { category in
                        quickChip(for: category)
                    }
                }
                .padding(.leading, 16)
            }
            // Leaves the last chip clear of the controls rather than letting it
            // stop hard against them.
            .contentMargins(.trailing, 10, for: .scrollContent)
            mapControls
                .padding(.trailing, 16)
                .layoutPriority(1)
        }
    }

    private func quickChip(for category: Category) -> some View {
        let isOn = model.categorySlugs.contains(category.slug)
        return Button {
            model.toggleQuickCategory(category.slug)
        } label: {
            Text("\(category.icon ?? "📍") \(category.name)")
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .background(Capsule().fill(isOn ? VLTheme.indigo : Color.clear))
        .vlGlass(radius: 20)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    /// Near-me, radius and basemap style, all the same size and side by side.
    private var mapControls: some View {
        HStack(spacing: 6) {
            Button {
                useNearMe.toggle()
                if useNearMe {
                    location.requestCurrentLocation()
                } else {
                    searchCenter = mapRegion.center
                    Task { await runSearch() }
                }
            } label: {
                controlLabel { Image(systemName: useNearMe ? "location.fill" : "location.viewfinder") }
            }
            .vlGlass(tint: useNearMe ? VLTheme.indigo : nil, radius: 14)
            .foregroundStyle(useNearMe ? Color.white : Color.primary)
            .accessibilityIdentifier("explore-near-me")
            .accessibilityLabel("Cerca de mí")
            .accessibilityAddTraits(useNearMe ? [.isSelected] : [])

            Menu {
                Picker("Radio", selection: $radiusMeters) {
                    ForEach(Self.radiusSteps, id: \.self) { step in
                        Text(RouteFormat.distance(step)).tag(step)
                    }
                }
            } label: {
                controlLabel { Text(RouteFormat.distance(radiusMeters)).font(.caption.weight(.bold)) }
            }
            .vlGlass(radius: 14)
            .accessibilityLabel("Radio de búsqueda")

            Menu {
                Picker("Estilo del mapa", selection: $mapStyle) {
                    ForEach(MapStyleOption.allCases) { style in
                        Label(style.label, systemImage: style.symbol).tag(style)
                    }
                }
            } label: {
                controlLabel { Image(systemName: "square.3.layers.3d") }
            }
            .vlGlass(radius: 14)
            .accessibilityLabel("Estilo del mapa")
        }
    }

    /// One size for every map control, so the row reads as a single unit.
    private func controlLabel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.subheadline.weight(.semibold))
            .frame(width: 34, height: 30)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Lugares, eventos, direcciones…", text: $model.query)
                .submitLabel(.search).onSubmit { Task { await runSearch() } }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    Task { await runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12).vlGlass(radius: 16).padding(.horizontal, 16)
        .accessibilityIdentifier("explore-search")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 24) }
                ForEach(model.items) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) { VLItemCard(item: item) }
                        .buttonStyle(.plain)
                }
                if let error = model.errorMessage {
                    ContentUnavailableView("No se pudo actualizar", systemImage: "wifi.exclamationmark", description: Text(error))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
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
                projection: projection,
                mapStyle: mapStyle,
                route: routeService.route,
                isGuiding: routeService.isGuiding,
                onRegionChange: { newRegion in
                    guard showMap, !useNearMe, !isUITesting else { return }
                    searchCenter = newRegion.center
                    Task { await model.search(center: newRegion.center, radiusMeters: radiusMeters) }
                }
            )
            MapRadiusRing(projection: projection, isHidden: routeService.route != nil)
            if useNearMe, let message = location.errorMessage {
                Text(message)
                    .font(.caption)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .vlGlass(tint: VLTheme.coral, radius: 12)
                    .padding(.horizontal, 16)
                    .padding(.top, headerHeight + 8)
            }
            if location.isRequesting {
                ProgressView().controlSize(.small).padding(.top, headerHeight + 8).padding(.trailing, 20)
            }
        }
    }

    // MARK: - Actions

    /// Frames the requested radius with margin so the ring is fully visible.
    static func region(around center: CLLocationCoordinate2D, radiusMeters: CLLocationDistance) -> MKCoordinateRegion {
        MKCoordinateRegion(center: center, latitudinalMeters: radiusMeters * 2.6, longitudinalMeters: radiusMeters * 2.6)
    }

    private func runSearch() async {
        if useNearMe, let coordinate = location.coordinate {
            await model.search(
                center: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng),
                radiusMeters: radiusMeters
            )
        } else if showMap {
            await model.search(center: mapRegion.center, radiusMeters: radiusMeters)
        } else {
            await model.search()
        }
    }

    private func startRoute(to item: ExploreItem) async {
        guard let target = item.coordinate else { return }
        let resolved = location.location?.coordinate
            ?? location.coordinate.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        guard let origin = resolved else {
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

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

import CoreLocation
import MapKit
import SwiftUI

struct ExploreView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SessionStore.self) private var session
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
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
    /// Guards the "search this area" reaction while the map is being moved by
    /// the preview rail rather than by the user's finger.
    @State private var suppressAreaSearchUntil = Date.distantPast

    private static let radiusSteps: [CLLocationDistance] = [100, 500, 1_000, 2_000, 3_000, 5_000]

    var body: some View {
        @Bindable var deepLinkRouter = deepLinkRouter
        return NavigationStack(path: $deepLinkRouter.explorePath) {
            ZStack(alignment: .top) {
                content
                // The rail is part of the map rather than something presented
                // over it: it stays up while the user pans, and it is what a
                // tapped pin scrolls to. Its selection is the map's selection.
                // It lives here, outside the map's `ignoresSafeArea`, so it
                // clears the tab bar.
                if showMap, !model.items.isEmpty, routeService.destination == nil {
                    VStack {
                        Spacer()
                        MapCardCarouselView(
                            items: model.items,
                            selectedID: $selectedMapItemID,
                            onDirections: { item in Task { await startRoute(to: item) } }
                        )
                        .padding(.bottom, 12)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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
            .vlScreen()
            .navigationDestination(for: DeepLinkRouter.Destination.self) { DeepLinkDestinationView(destination: $0) }
            // The screen's own header carries the search field and its actions,
            // so the navigation bar would only add a second, emptier one.
            .toolbar(.hidden, for: .navigationBar)
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
            // Most venues are illustrated by their Google photo, and the rail
            // is the first place that photo is asked for. Starting the fetch as
            // the pin is selected means the card usually scrolls in with the
            // picture already decoded instead of on a placeholder.
            .onChange(of: selectedMapItemID) { _, id in
                guard let id, let item = model.items.first(where: { $0.id == id }) else { return }
                // Swiping the rail is also a way of moving around the map, so
                // the camera follows the card that is in view. The radius is
                // kept, so only the centre moves.
                if let coordinate = item.coordinate {
                    let center = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
                    // Re-searching the area the card just centred would swap the
                    // results out from under the rail the user is swiping.
                    suppressAreaSearchUntil = .now.addingTimeInterval(1.5)
                    withAnimation(reduceMotion ? nil : Animation.snappy) {
                        mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters)
                    }
                }
                guard case .venue(let venue) = item else { return }
                Task.detached(priority: .userInitiated) {
                    _ = try? await GoogleVenuePhotoClient.shared.load(slug: venue.slug, large: false)
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
            topRow
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

    /// Quick category chips. The map controls used to share this row and had to
    /// be defended from it; they float over the map now, so the chips get the
    /// full width and only need to clip at the trailing fade.
    private var controlRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Date shortcuts lead: "what is on tonight" is the most
                    // common question this screen answers.
                    ForEach(ExploreViewModel.DatePreset.allCases) { preset in
                        dateChip(for: preset)
                    }
                    Divider().frame(height: 20)
                    ForEach(model.quickCategories, id: \.id) { category in
                        quickChip(for: category)
                    }
                }
                .padding(.leading, 16)
            }
            // Leaves the last chip clear of the controls rather than letting it
            // stop hard against them.
            .contentMargins(.trailing, 10, for: .scrollContent)
            .mask(chipFade)
        }
    }

    /// Near-me, radius and basemap style. Stacked on the right edge of the map
    /// so the header only carries search, filters and the list switch.
    private var mapControls: some View {
        VStack(spacing: 8) {
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

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 24) }
                ForEach(model.items) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) { VLItemCard(item: item) }
                        .buttonStyle(.plain)
                        .onAppear {
                            // Scroll infinito: al ver el ultimo resultado se pide la
                            // siguiente pagina con los skips que devuelve el backend.
                            guard item.id == model.items.last?.id, model.canLoadMore else { return }
                            Task { await model.loadMore() }
                        }
                }
                if model.isLoadingMore { ProgressView().padding(.vertical, 12) }
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
                    // The rail moves the camera too; that is following a result,
                    // not asking for new ones.
                    guard Date.now >= suppressAreaSearchUntil else { return }
                    searchCenter = newRegion.center
                    Task { await model.search(center: newRegion.center, radiusMeters: radiusMeters) }
                }
            )
            if let tint = VLTheme.mapTint {
                // Hue only: see VLTheme.mapTint. Never hit-tested, so panning
                // and pin taps go straight through to MKMapView.
                tint
                    .opacity(VLTheme.mapTintOpacity)
                    .blendMode(.color)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
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
                // Left of the control stack, which now owns the trailing edge.
                ProgressView().controlSize(.small).padding(.top, headerHeight + 22).padding(.trailing, 66)
            }
            mapControls
                .padding(.trailing, 14)
                .padding(.top, headerHeight + 12)
        }
        // Keeps the map tint's blend inside this stack instead of letting it
        // colour whatever the explore screen is drawn on top of.
        .compositingGroup()
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

// Chip builders for the control row. Kept in an extension so ExploreView's
// own body stays within the linter's type body limit.
private extension ExploreView {
    /// Touch-target sized twin of `controlLabel` for the buttons that sit
    /// beside the search field, so the whole row is one 44pt band.
    private func headerLabel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.subheadline.weight(.semibold))
            .frame(width: 44, height: 44)
    }

    /// One size for every map control, so the stack reads as a single unit.
    private func controlLabel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.subheadline.weight(.semibold))
            .frame(width: 40, height: 40)
    }

    /// Back (only when there is something to go back from), search, filters and
    /// the map/list switch — the whole top of the screen in one row.
    private var topRow: some View {
        HStack(spacing: 10) {
            if showsBackButton {
                Button { resetExplore() } label: {
                    headerLabel { Image(systemName: "chevron.left") }
                }
                .vlGlass(radius: 16)
                .accessibilityIdentifier("explore-back")
                .accessibilityLabel("Limpiar búsqueda")
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            searchBar
            Button { showFilters = true } label: {
                headerLabel {
                    Image(systemName: model.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
            }
            .vlGlass(tint: model.activeFilterCount > 0 ? VLTheme.indigo : nil, radius: 16)
            .foregroundStyle(model.activeFilterCount > 0 ? Color.white : Color.primary)
            .accessibilityIdentifier("explore-filters")
            .accessibilityLabel(model.activeFilterCount > 0 ? "Filtros, \(model.activeFilterCount) activos" : "Filtros de exploración")

            Button {
                if reduceMotion { showMap.toggle() } else { withAnimation(.snappy) { showMap.toggle() } }
            } label: {
                headerLabel { Image(systemName: showMap ? "list.bullet" : "map") }
            }
            .vlGlass(radius: 16)
            .accessibilityLabel(showMap ? "Ver lista" : "Ver mapa")
        }
        .padding(.horizontal, 16)
        .animation(reduceMotion ? nil : .snappy, value: showsBackButton)
    }

    /// Nothing is pushed on top of Explore at the root, so the arrow stands for
    /// the state the user built up: a query, active filters or a selected pin.
    private var showsBackButton: Bool {
        !model.query.isEmpty || model.activeFilterCount > 0 || selectedMapItemID != nil
    }

    private func resetExplore() {
        selectedMapItemID = nil
        model.query = ""
        model.type = "all"
        model.resetFilters()
        Task { await runSearch() }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                if model.query.isEmpty { RotatingSearchPlaceholder() }
                TextField("", text: $model.query)
                    .submitLabel(.search).onSubmit { Task { await runSearch() } }
                    .accessibilityIdentifier("explore-search")
                    .accessibilityLabel("Buscar lugares, eventos y direcciones")
            }
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    Task { await runSearch() }
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .vlGlass(radius: 16)
    }

/// Softens the edge the chips now clip against. A fixed-width ramp rather
    /// than a percentage, so the fade looks the same whatever the row's width
    /// works out to once the map controls have taken theirs.
    private var chipFade: some View {
        HStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 24)
        }
    }

    private func dateChip(for preset: ExploreViewModel.DatePreset) -> some View {
        let isOn = model.isDatePresetActive(preset)
        return Button {
            model.toggleDatePreset(preset)
            Task { await runSearch() }
        } label: {
            Label(preset.label, systemImage: preset.icon)
                .font(.footnote.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .background(Capsule().fill(isOn ? VLTheme.coral : Color.clear))
        .vlGlass(radius: 20)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
        .accessibilityLabel("Eventos: \(preset.label)")
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
}

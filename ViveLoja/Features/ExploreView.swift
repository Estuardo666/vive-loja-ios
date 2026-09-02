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
    @State private var nearMeCenter: CLLocationCoordinate2D?
    @State private var selectedMapItemID: String?
    @State private var radiusMeters: CLLocationDistance = 1_000
    @State private var showMap = false
    @State private var showFilters = false
    @State private var location = LocationService()
    @State private var useNearMe = false

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
            .task { if !isUITesting { await model.search(); await model.loadCategories() } }
            .onChange(of: model.type) { _, _ in
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: location.coordinate?.lat) { _, _ in
                guard useNearMe, let coordinate = location.coordinate else { return }
                let center = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
                nearMeCenter = center
                withAnimation(reduceMotion ? nil : Animation.snappy) { mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters) }
                guard !isUITesting else { return }
                Task { await runSearch() }
            }
            .onChange(of: radiusMeters) { _, _ in
                let center = nearMeCenter ?? mapRegion.center
                withAnimation(reduceMotion ? nil : Animation.snappy) { mapRegion = ExploreView.region(around: center, radiusMeters: radiusMeters) }
                guard showMap || useNearMe, !isUITesting else { return }
                Task { await runSearch() }
            }
            .sheet(isPresented: Binding(get: { selectedMapItemID != nil }, set: { if !$0 { selectedMapItemID = nil } })) {
                if let selectedMapItemID, let item = model.items.first(where: { $0.id == selectedMapItemID }) {
                    MapItemPeekView(item: item)
                        .presentationDetents([.height(300), .large])
                        .presentationDragIndicator(.visible)
                        .presentationBackgroundInteraction(.enabled(upThrough: .height(300)))
                }
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
                circleCenter: useNearMe ? nearMeCenter : nil,
                onRegionChange: { newRegion in
                    guard showMap, !useNearMe, !isUITesting else { return }
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
                        nearMeCenter = nil
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

private struct ExploreFiltersView: View {
    @Bindable var model: ExploreViewModel
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                if !model.categories.isEmpty {
                    Section("Categoría") {
                        ForEach(model.categories, id: \.id) { category in
                            Button {
                                if let index = model.categorySlugs.firstIndex(of: category.slug) {
                                    model.categorySlugs.remove(at: index)
                                } else {
                                    model.categorySlugs.append(category.slug)
                                }
                            } label: {
                                HStack {
                                    Text("\(category.icon ?? "📍")  \(category.name)").foregroundStyle(.primary)
                                    Spacer()
                                    if model.categorySlugs.contains(category.slug) {
                                        Image(systemName: "checkmark").foregroundStyle(VLTheme.indigo)
                                    }
                                }
                            }
                            .accessibilityAddTraits(model.categorySlugs.contains(category.slug) ? [.isSelected] : [])
                        }
                    }
                }
                Section("Generales") {
                    Picker("Calificación mínima", selection: Binding(get: { model.minRating ?? 0 }, set: { model.minRating = $0 == 0 ? nil : $0 })) {
                        Text("Cualquiera").tag(Double(0))
                        Text("3 estrellas").tag(Double(3))
                        Text("4 estrellas").tag(Double(4))
                        Text("4.5 estrellas").tag(Double(4.5))
                    }
                    Toggle("Abierto ahora", isOn: $model.openNow)
                    Toggle("Verificados", isOn: $model.verified)
                    Toggle("Con promociones", isOn: $model.hasPromotions)
                    Toggle("Con próximos eventos", isOn: $model.hasUpcomingEvents)
                }
                Section("Locales") {
                    Picker("Precio", selection: Binding(get: { model.priceRange ?? "" }, set: { model.priceRange = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag("")
                        Text("$").tag("$"); Text("$$").tag("$$"); Text("$$$").tag("$$$"); Text("$$$$").tag("$$$$")
                    }
                    Picker("Servicio", selection: Binding(get: { model.services.first ?? "" }, set: { model.services = $0.isEmpty ? [] : [$0] })) {
                        Text("Cualquiera").tag("")
                        Text("Reservas").tag("Reservas"); Text("Delivery").tag("Delivery"); Text("Wi-Fi").tag("Wi-Fi")
                    }
                }
                Section("Eventos") {
                    Picker("Precio del evento", selection: Binding(get: { model.eventPrice ?? "" }, set: { model.eventPrice = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag(""); Text("Gratis").tag("free"); Text("De pago").tag("paid")
                    }
                    Picker("Fecha", selection: Binding(get: { model.eventDatePreset ?? "" }, set: { model.eventDatePreset = $0.isEmpty ? nil : $0 })) {
                        Text("Cualquiera").tag(""); Text("Hoy").tag("today"); Text("Mañana").tag("tomorrow"); Text("Este fin de semana").tag("thisWeekend")
                    }
                    TextField("Precio máximo", value: Binding(
                        get: { model.eventMaxPrice ?? 0 },
                        set: { model.eventMaxPrice = $0 == 0 ? nil : $0 }
                    ), format: .number)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Filtros")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Restablecer") { model.resetFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Aplicar") { onApply(); dismiss() }
                }
            }
        }
    }
}

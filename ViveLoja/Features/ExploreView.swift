import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ExploreViewModel {
    var query = ""
    var type = "all"
    var items: [ExploreItem] = HomeViewModel.fixtures
    var isLoading = false
    var errorMessage: String?

    func search(region: MKCoordinateRegion? = nil, radiusMeters: CLLocationDistance? = nil) async {
        isLoading = true
        defer { isLoading = false }
        var queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: type), URLQueryItem(name: "take", value: "60")]
        if let region, let radiusMeters {
            queryItems += [
                URLQueryItem(name: "lat", value: String(region.center.latitude)),
                URLQueryItem(name: "lng", value: String(region.center.longitude)),
                URLQueryItem(name: "radius", value: String(radiusMeters)),
            ]
        }
        queryItems.removeAll { $0.value?.isEmpty == true }
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            items = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }
}

struct ExploreView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model = ExploreViewModel()
    @State private var mapRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08))
    @State private var selectedMapItemID: String?
    @State private var radiusMeters: CLLocationDistance = 1_000
    @State private var showMap = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Picker("Tipo", selection: $model.type) {
                    Text("Todo").tag("all"); Text("Locales").tag("venues"); Text("Eventos").tag("events")
                }
                .pickerStyle(.segmented).padding(.horizontal, 16).padding(.vertical, 10)
                if showMap { map } else { list }
            }
            .navigationTitle("Explorar")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button {
                if reduceMotion { showMap.toggle() } else { withAnimation(.snappy) { showMap.toggle() } }
            } label: { Image(systemName: showMap ? "list.bullet" : "map") }.accessibilityLabel(showMap ? "Ver lista" : "Ver mapa") } }
            .task { if !isUITesting { await model.search() } }
            .onChange(of: model.type) { _, _ in Task { await model.search() } }
            .onChange(of: radiusMeters) { _, _ in
                guard showMap else { return }
                Task { await model.search(region: mapRegion, radiusMeters: radiusMeters) }
            }
            .sheet(isPresented: Binding(get: { selectedMapItemID != nil }, set: { if !$0 { selectedMapItemID = nil } })) {
                if let selectedMapItemID, let item = model.items.first(where: { $0.id == selectedMapItemID }) {
                    NavigationStack { ItemDetailView(item: item) }
                }
            }
        }
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
                onRegionChange: { newRegion in
                    guard showMap else { return }
                    Task { await model.search(region: newRegion, radiusMeters: radiusMeters) }
                }
            )
                .ignoresSafeArea(edges: .bottom)
            Picker("Radio", selection: $radiusMeters) {
                Text("100 m").tag(CLLocationDistance(100))
                Text("500 m").tag(CLLocationDistance(500))
                Text("1 km").tag(CLLocationDistance(1_000))
                Text("2 km").tag(CLLocationDistance(2_000))
                Text("3 km").tag(CLLocationDistance(3_000))
                Text("5 km").tag(CLLocationDistance(5_000))
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .vlGlass(tint: VLTheme.indigo, radius: 14)
            .padding(16)
            .accessibilityLabel("Radio de búsqueda")
        }
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

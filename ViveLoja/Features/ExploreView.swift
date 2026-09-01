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

    func search() async {
        isLoading = true
        defer { isLoading = false }
        var queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: type), URLQueryItem(name: "take", value: "60")]
        queryItems.removeAll { $0.value?.isEmpty == true }
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            items = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }
}

struct ExploreView: View {
    @State private var model = ExploreViewModel()
    @State private var cameraPosition: MapCameraPosition = .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: -3.99313, longitude: -79.20422), span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)))
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
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { withAnimation(.snappy) { showMap.toggle() } } label: { Image(systemName: showMap ? "list.bullet" : "map") }.accessibilityLabel(showMap ? "Ver lista" : "Ver mapa") } }
            .task { await model.search() }
            .onChange(of: model.type) { _, _ in Task { await model.search() } }
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
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 24) }
                ForEach(model.items) { item in NavigationLink(destination: ItemPlaceholderView(item: item)) { VLItemCard(item: item) }.buttonStyle(.plain) }
                if let error = model.errorMessage { ContentUnavailableView("No se pudo actualizar", systemImage: "wifi.exclamationmark", description: Text(error)) }
            }
            .padding(16)
        }
    }

    private var map: some View {
        Map(position: $cameraPosition) {
            ForEach(model.items) { item in
                if let coordinate = item.coordinate {
                    Annotation(item.title, coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)) {
                        Image(systemName: isVenue(item) ? "mappin.circle.fill" : "calendar.circle.fill")
                            .font(.title2).foregroundStyle(VLTheme.itemColor(item)).background(.background, in: Circle())
                            .accessibilityLabel(item.title)
                    }
                }
            }
            UserAnnotation()
        }
        .mapStyle(.standard(elevation: .realistic))
        .mapControls { MapUserLocationButton(); MapCompass() }
        .ignoresSafeArea(edges: .bottom)
    }

    private func isVenue(_ item: ExploreItem) -> Bool {
        if case .venue = item { return true }
        return false
    }
}

struct ItemPlaceholderView: View {
    let item: ExploreItem
    var body: some View { ScrollView { VLItemCard(item: item).padding(20) }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline) }
}

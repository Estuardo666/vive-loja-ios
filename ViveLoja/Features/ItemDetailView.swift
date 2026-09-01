import MapKit
import SwiftUI

struct ItemDetailView: View {
    let item: ExploreItem
    @Environment(SavedStore.self) private var saved
    @Environment(\.openURL) private var openURL
    @State private var resolvedItem: ExploreItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VLAsyncImage(url: imageURL, height: 250).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 10) {
                    Text(displayedItem.title).font(.largeTitle.weight(.bold))
                    Text(location).font(.headline).foregroundStyle(.secondary)
                    Text(description).font(.body)
                }
                HStack(spacing: 12) {
                    Button { saved.toggle(displayedItem) } label: {
                        Label(saved.contains(displayedItem) ? "Guardado" : "Guardar", systemImage: saved.contains(displayedItem) ? "heart.fill" : "heart")
                    }.buttonStyle(.borderedProminent).tint(VLTheme.indigo)
                    ShareLink(item: "\(displayedItem.title) — Vive Loja") { Label("Compartir", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                }
                if let coordinate = displayedItem.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(displayedItem.title, coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng))
                    }.frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Button("Abrir en Apple Maps", systemImage: "map") {
                        openURL(URL(string: "http://maps.apple.com/?ll=\(coordinate.lat),\(coordinate.lng)")!)
                    }.buttonStyle(.bordered)
                }
            }.padding(20)
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
    }

    private var displayedItem: ExploreItem { resolvedItem ?? item }

    private func loadDetail() async {
        do {
            switch item {
            case .venue(let value):
                let detail: ExploreVenue = try await APIClient.shared.get("/venues/\(value.slug)")
                resolvedItem = .venue(detail)
            case .event(let value):
                let detail: ExploreEvent = try await APIClient.shared.get("/events/\(value.slug)")
                resolvedItem = .event(detail)
            }
        } catch {
            // Fixtures remain visible when the device is offline or the item was removed.
        }
    }

    private var imageURL: URL? {
        switch displayedItem { case .venue(let value): return value.image; case .event(let value): return value.image }
    }
    private var location: String {
        switch displayedItem { case .venue(let value): return value.location ?? "Loja"; case .event(let value): return value.location ?? "Loja" }
    }
    private var description: String {
        switch displayedItem { case .venue(let value): return value.description ?? "Descubre este lugar en Loja."; case .event(let value): return value.description ?? "Un evento para vivir Loja." }
    }
}

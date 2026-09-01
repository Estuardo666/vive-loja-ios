import MapKit
import SwiftUI

struct ItemDetailView: View {
    let item: ExploreItem
    @Environment(SavedStore.self) private var saved
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VLAsyncImage(url: imageURL, height: 250).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.title).font(.largeTitle.weight(.bold))
                    Text(location).font(.headline).foregroundStyle(.secondary)
                    Text(description).font(.body)
                }
                HStack(spacing: 12) {
                    Button { saved.toggle(item) } label: {
                        Label(saved.contains(item) ? "Guardado" : "Guardar", systemImage: saved.contains(item) ? "heart.fill" : "heart")
                    }.buttonStyle(.borderedProminent).tint(VLTheme.indigo)
                    ShareLink(item: "\(item.title) — Vive Loja") { Label("Compartir", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                }
                if let coordinate = item.coordinate {
                    Map(initialPosition: .region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))) {
                        Marker(item.title, coordinate: CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng))
                    }.frame(height: 200).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Button("Abrir en Apple Maps", systemImage: "map") {
                        openURL(URL(string: "http://maps.apple.com/?ll=\(coordinate.lat),\(coordinate.lng)")!)
                    }.buttonStyle(.bordered)
                }
            }.padding(20)
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var imageURL: URL? {
        switch item { case .venue(let value): return value.image; case .event(let value): return value.image }
    }
    private var location: String {
        switch item { case .venue(let value): return value.location ?? "Loja"; case .event(let value): return value.location ?? "Loja" }
    }
    private var description: String {
        switch item { case .venue(let value): return value.description ?? "Descubre este lugar en Loja."; case .event(let value): return value.description ?? "Un evento para vivir Loja." }
    }
}

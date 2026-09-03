import CoreLocation
import MapKit
import SwiftUI

/// Detail sections ported from the web experience (`venue-detail.tsx` sidebar).
/// They live outside `ItemDetailView` so that view's body stays within SwiftLint limits.

/// A single labelled row inside the "Información" card.
struct VLInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(VLTheme.indigo)
                .frame(width: 32, height: 32)
                .background(VLTheme.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// "Información" card: address, phone, website and price range.
/// Mirrors the info card the web detail page shows in its sidebar.
struct ItemInfoSection: View {
    let address: String?
    let phone: String?
    let website: URL?
    let priceRange: String?
    @Environment(\.openURL) private var openURL

    private var hasContent: Bool {
        address != nil || phone != nil || website != nil || priceRange != nil
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 12) {
                Text("Información").font(.title2.weight(.semibold))
                if let address {
                    VLInfoRow(icon: "mappin.and.ellipse", label: "Dirección", value: address)
                }
                if let phone, let url = Self.telURL(for: phone) {
                    Button { openURL(url) } label: {
                        VLInfoRow(icon: "phone.fill", label: "Teléfono", value: phone)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Llamar")
                } else if let phone {
                    VLInfoRow(icon: "phone.fill", label: "Teléfono", value: phone)
                }
                if let website {
                    Button { openURL(website) } label: {
                        VLInfoRow(icon: "globe", label: "Sitio web", value: website.host ?? website.absoluteString)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abrir sitio web")
                }
                if let priceRange {
                    VLInfoRow(icon: "dollarsign.circle.fill", label: "Rango de precios", value: priceRange)
                }
            }
            .padding(16)
            .vlGlass(radius: 20)
        }
    }

    /// Strips formatting so `tel:` receives only dialable characters.
    static func telURL(for phone: String) -> URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }
}

/// Category pill shown at the end of the detail screen.
struct ItemCategorySection: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            Text(category.icon ?? "📍").font(.largeTitle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Categoría").font(.caption).foregroundStyle(.secondary)
                Text(category.name).font(.subheadline.weight(.semibold))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .vlGlass(radius: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Categoría: \(category.name)")
    }
}

/// Deep link into the Uber app, matching the web build in `lib/transport/uber-link.ts`.
struct UberRideButton: View {
    let latitude: Double
    let longitude: Double
    let destinationName: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url = Self.uberURL(latitude: latitude, longitude: longitude, name: destinationName) {
            Button { openURL(url) } label: {
                Label("Ir con Uber", systemImage: "car.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .accessibilityLabel("Ir con Uber a \(destinationName)")
        }
    }

    /// Square brackets are not URL-legal, so the `dropoff[...]` keys are percent-encoded.
    static func uberURL(latitude: Double, longitude: Double, name: String) -> URL? {
        var components = URLComponents(string: "https://m.uber.com/ul/")
        components?.percentEncodedQuery = [
            "action=setPickup",
            "pickup=my_location",
            "dropoff%5Blatitude%5D=\(latitude)",
            "dropoff%5Blongitude%5D=\(longitude)",
            "dropoff%5Bnickname%5D=\(name.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "")",
        ].joined(separator: "&")
        return components?.url
    }
}


/// Verification badge, owner shortcut and the claim call to action. Only one of
/// them applies at a time, driven by the flags the venue endpoint adds when the
/// request carries a session.
struct VenueOwnerSection: View {
    let venue: ExploreVenue
    let detail: VenueDetail?
    let onClaim: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if detail?.verified ?? venue.verified {
                Label("Negocio verificado", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(VLTheme.emerald)
            }

            if detail?.isOwnedByMe == true {
                NavigationLink {
                    BusinessDashboardView(slug: venue.slug)
                } label: {
                    Label("Panel de mi negocio", systemImage: "chart.bar.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(VLTheme.indigo)
            } else if detail?.canReclaim == true {
                VStack(alignment: .leading, spacing: 6) {
                    Text("¿Eres el dueño de este negocio?")
                        .font(.subheadline.weight(.semibold))
                    Text("Reclámalo para responder reseñas, actualizar la información y ver tus métricas.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // `canReclaim` is only true when the request carried a
                    // session, so the CTA never appears to a signed-out reader.
                    Button("Reclamar este negocio", systemImage: "person.badge.shield.checkmark", action: onClaim)
                        .buttonStyle(.bordered)
                        .tint(VLTheme.emerald)
                }
                .padding(14)
                .vlGlass(tint: VLTheme.emerald.opacity(0.08))
            }
        }
    }
}


/// Menu of a venue, grouped by category. Only available items are listed.
struct VenueMenuSection: View {
    let categories: [MobileMenuCategory]

    var body: some View {
        if !categories.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Menú").font(.title2.weight(.semibold))
                ForEach(categories) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.name).font(.headline)
                        ForEach(category.items.filter(\.isAvailable)) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline.weight(.semibold))
                                    if let description = item.description {
                                        Text(description).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if let price = item.price {
                                    Text(price, format: .currency(code: "USD")).font(.subheadline.weight(.semibold))
                                }
                            }
                        }
                    }
                    .padding(12)
                    .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}

/// Products a venue sells, as opposed to menu items it serves.
struct VenueProductsSection: View {
    let products: [MobileProduct]

    var body: some View {
        let available = products.filter(\.isAvailable)
        if !available.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Productos").font(.title2.weight(.semibold))
                ForEach(available) { product in
                    HStack(spacing: 10) {
                        VLAsyncImage(url: product.image, height: 56)
                            .frame(width: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(product.name).font(.subheadline.weight(.semibold))
                            if let description = product.description {
                                Text(description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                        Spacer()
                        if let price = product.price {
                            Text(price, format: .currency(code: "USD")).font(.caption.weight(.semibold))
                        }
                    }
                    .padding(10)
                    .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}


/// Map, Apple Maps hand-off and the Uber deep link for anything with a
/// coordinate. Renders nothing when the item has none.
struct ItemLocationSection: View {
    let coordinate: (lat: Double, lng: Double)?
    let title: String

    var body: some View {
        if let coordinate {
            let center = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
            Group {
                if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                    ZStack {
                        VLTheme.surface
                        Image(systemName: "map.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.secondary)
                        VStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title)
                                .foregroundStyle(VLTheme.indigo)
                            Text(title)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Mapa de \(title)")
                } else {
                    Map(
                        initialPosition: .region(
                            MKCoordinateRegion(
                                center: center,
                                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                            )
                        )
                    ) {
                        Marker(title, coordinate: center)
                    }
                }
            }
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            if let mapsURL = URL(string: "http://maps.apple.com/?ll=\(coordinate.lat),\(coordinate.lng)") {
                Link(destination: mapsURL) {
                    Label("Abrir en Apple Maps", systemImage: "map")
                }
                .buttonStyle(.bordered)
            }

            UberRideButton(latitude: coordinate.lat, longitude: coordinate.lng, destinationName: title)
        }
    }
}

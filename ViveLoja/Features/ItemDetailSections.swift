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

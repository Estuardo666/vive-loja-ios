import Observation
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var featured: [ExploreItem] = HomeViewModel.fixtures
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload: HomePayload = try await APIClient.shared.get("/home")
            featured = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
            categories = payload.categories
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }

    static let fixtures: [ExploreItem] = [
        .venue(ExploreVenue(id: "fixture-venue-1", name: "Café Loja", slug: "cafe-loja", description: "Café de altura y ambiente acogedor.", image: URL(string: "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?w=800"), location: "Centro histórico", address: "Calle Bolívar, Loja", lat: -4.0079, lng: -79.2045, featured: true, phone: nil, website: nil, priceRange: "$$", avgRating: 4.8, reviewCount: 32, verified: true, categories: [])),
        .event(ExploreEvent(id: "fixture-event-1", title: "Música en vivo", slug: "musica-en-vivo", description: "Una noche para disfrutar artistas locales.", image: URL(string: "https://images.unsplash.com/photo-1470229722913-7c0e2dbbafd3?w=800"), startDate: Date().addingTimeInterval(86400), endDate: nil, location: "Teatro Benjamín Carrión", address: "Loja", lat: -3.9931, lng: -79.2042, featured: true, price: 0, avgRating: nil, reviewCount: 0, categories: []))
    ]
}

struct HomeView: View {
    @State private var model = HomeViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    hero
                    VStack(alignment: .leading, spacing: 14) {
                        VLSectionHeader(title: "Destacados", action: nil)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(model.featured) { item in
                                    NavigationLink(destination: ItemDetailView(item: item)) {
                                        VLItemCard(item: item).frame(width: 265)
                                    }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        VLSectionHeader(title: "Explora Loja", action: nil)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            if model.categories.isEmpty {
                                category("🍽️", "Restaurantes", VLTheme.coral)
                                category("🎵", "Eventos", VLTheme.indigo)
                                category("☕", "Cafeterías", .brown)
                                category("🌿", "Rutas", VLTheme.emerald)
                            } else {
                                ForEach(model.categories.prefix(6), id: \.id) { value in
                                    category(value.icon ?? "✨", value.name, color(for: value.color))
                                }
                            }
                        }
                    }
                    NavigationLink(destination: ContentHubView()) {
                        Label("Todo lo que pasa en Loja", systemImage: "sparkles")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.indigo)
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 30)
            }
            .navigationTitle("Vive Loja")
            .refreshable { await model.load() }
            .task { await model.load() }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Loja está viva").font(.system(size: 38, weight: .bold, design: .rounded)).tracking(-1.2)
            Text("Descubre eventos, locales y planes cerca de ti.").font(.title3).foregroundStyle(.secondary)
            NavigationLink(destination: ExploreView()) {
                Label("Explorar el mapa", systemImage: "map.fill").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent).tint(VLTheme.indigo)
        }
        .padding(20).vlGlass(tint: VLTheme.indigo.opacity(0.12), radius: 26)
    }

    private func category(_ emoji: String, _ title: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) { Text(emoji).font(.title); Text(title).font(.headline) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(16)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(color.opacity(0.2)) }
    }

    private func color(for value: String?) -> Color {
        guard let value else { return VLTheme.indigo }
        let lowercased = value.lowercased()
        if lowercased.contains("coral") || lowercased.contains("red") { return VLTheme.coral }
        if lowercased.contains("green") || lowercased.contains("emerald") { return VLTheme.emerald }
        return VLTheme.indigo
    }
}

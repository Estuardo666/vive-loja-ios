import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.isRestoring { ProgressView("Cargando Vive Loja…") }
            else { MainTabView() }
        }
        .tint(VLTheme.indigo)
    }
}

struct MainTabView: View {
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @State private var selectedTab = Tab.home

    enum Tab: Hashable { case home, explore, saved, messages, account }

    var body: some View {
        @Bindable var deepLinkRouter = deepLinkRouter
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(Tab.home)
            ExploreView().tabItem { Label("Explorar", systemImage: "map.fill") }.tag(Tab.explore)
            SavedView().tabItem { Label("Guardados", systemImage: "heart.fill") }.tag(Tab.saved)
            MessagesPlaceholderView().tabItem { Label("Mensajes", systemImage: "message.fill") }.tag(Tab.messages)
            AccountView().tabItem { Label("Cuenta", systemImage: "person.crop.circle") }.tag(Tab.account)
        }
        .sheet(item: $deepLinkRouter.destination) { destination in
            DeepLinkDestinationView(destination: destination)
        }
    }
}

struct MessagesPlaceholderView: View { var body: some View { ContentUnavailableView("Tus mensajes", systemImage: "message", description: Text("Las conversaciones con locales aparecerán aquí.")) } }

private struct DeepLinkDestinationView: View {
    let destination: DeepLinkRouter.Destination

    var body: some View {
        switch destination {
        case .venue(let slug):
            ItemDetailView(item: .venue(ExploreVenue.placeholder(slug: slug)))
        case .event(let slug):
            ItemDetailView(item: .event(ExploreEvent.placeholder(slug: slug)))
        case .post:
            BlogView()
        }
    }
}

private extension ExploreVenue {
    static func placeholder(slug: String) -> ExploreVenue {
        ExploreVenue(id: "deep-link-venue-\(slug)", name: "Cargando…", slug: slug, description: nil, image: nil, location: nil, address: nil, lat: nil, lng: nil, featured: false, phone: nil, website: nil, priceRange: nil, avgRating: nil, reviewCount: 0, verified: false, categories: [])
    }
}

private extension ExploreEvent {
    static func placeholder(slug: String) -> ExploreEvent {
        ExploreEvent(id: "deep-link-event-\(slug)", title: "Cargando…", slug: slug, description: nil, image: nil, startDate: .now, endDate: nil, location: nil, address: nil, lat: nil, lng: nil, featured: false, price: nil, avgRating: nil, reviewCount: 0, categories: [])
    }
}

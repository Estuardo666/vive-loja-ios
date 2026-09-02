import SwiftUI
import UIKit

struct RootView: View {
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false

    var body: some View {
        @Bindable var session = session
        Group {
            if session.isRestoring { ProgressView("Cargando Vive Loja…") }
            else { MainTabView() }
        }
        .tint(VLTheme.indigo)
        .alert("Sesión vencida", isPresented: $session.isSessionExpired) {
            Button("Iniciar sesión") { showAuth = true }
            Button("Ahora no", role: .cancel) { }
        } message: {
            Text("Vuelve a iniciar sesión para continuar usando tus funciones personales.")
        }
        .sheet(isPresented: $showAuth) { AuthView() }
        .task(id: session.user?.id) { await session.loadAvatar() }
    }
}

struct MainTabView: View {
    @Environment(DeepLinkRouter.self) private var deepLinkRouter
    @Environment(SessionStore.self) private var session
    @State private var selectedTab = Tab.home
    @State private var avatarIcon: UIImage?

    enum Tab: Hashable { case home, explore, saved, messages, account }

    var body: some View {
        @Bindable var deepLinkRouter = deepLinkRouter
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(Tab.home)
            ExploreView().tabItem { Label("Explorar", systemImage: "map.fill") }.tag(Tab.explore)
            SavedView().tabItem { Label("Guardados", systemImage: "heart.fill") }.tag(Tab.saved)
            MessagesView().tabItem { Label("Mensajes", systemImage: "message.fill") }.tag(Tab.messages)
            AccountView().tabItem { accountTabLabel }.tag(Tab.account)
        }
        .task(id: session.avatarURL) { await loadAvatarIcon() }
        .sheet(item: $deepLinkRouter.destination) { destination in
            DeepLinkDestinationView(destination: destination)
        }
    }
}

@MainActor
extension MainTabView {
    @ViewBuilder
    var accountTabLabel: some View {
        if let avatarIcon {
            Label { Text("Cuenta") } icon: { Image(uiImage: avatarIcon) }
        } else {
            Label("Cuenta", systemImage: "person.crop.circle")
        }
    }

    /// Tab bar icons are template-rendered and tiny, so the avatar has to be
    /// cropped to a circle, resized and marked as original artwork or it would
    /// show up as a solid silhouette.
    func loadAvatarIcon() async {
        guard let url = session.avatarURL else { avatarIcon = nil; return }
        guard let image = await RemoteImageCache.shared.image(for: url) else { avatarIcon = nil; return }
        avatarIcon = MainTabView.circularTabIcon(from: image)
    }

    static func circularTabIcon(from image: UIImage, side: CGFloat = 26) -> UIImage {
        let size = CGSize(width: side, height: side)
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            let scale = max(side / image.size.width, side / image.size.height)
            let scaled = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(
                x: (side - scaled.width) / 2,
                y: (side - scaled.height) / 2,
                width: scaled.width,
                height: scaled.height
            ))
        }
        return rendered.withRenderingMode(.alwaysOriginal)
    }
}

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
        case .watchEvent(let slug):
            WatchEventDetailView(event: MobileWatchEvent.placeholder(slug: slug))
        }
    }
}

private extension MobileWatchEvent {
    static func placeholder(slug: String) -> MobileWatchEvent {
        MobileWatchEvent(id: "deep-link-watch-\(slug)", name: "Cargando…", slug: slug, type: "OTHER", description: nil, image: nil, matchDate: .now, matchTime: nil, competition: nil, performers: [], featured: false, viewCount: 0, venueCount: nil)
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

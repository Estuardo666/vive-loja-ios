import SwiftUI
import UIKit

struct RootView: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false

    var body: some View {
        @Bindable var session = session
        Group {
            if session.isRestoring { ProgressView("Cargando Vive Loja…") }
            else { MainTabView(selectedTab: $selectedTab) }
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
    /// Owned by the app so a palette change cannot reset it. See ViveLojaApp.
    @Binding var selectedTab: Tab
    @State private var avatarIcon: UIImage?

    enum Tab: Hashable { case home, explore, saved, messages, account }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(Tab.home)
            ExploreView().tabItem { Label("Explorar", systemImage: "map.fill") }.tag(Tab.explore)
            SavedView().tabItem { Label("Guardados", systemImage: "heart.fill") }.tag(Tab.saved)
            MessagesView().tabItem { Label("Mensajes", systemImage: "message.fill") }.tag(Tab.messages)
            AccountView().tabItem { accountTabLabel }.tag(Tab.account)
        }
        // Environment-backed, so it reaches every List and ScrollView below.
        // This used to be a TapGesture attached to the whole TabView, which
        // competed with the row selection inside every List and left the
        // buttons on the account screen dead to the touch.
        .scrollDismissesKeyboard(.interactively)
        .task(id: session.avatarURL) { await loadAvatarIcon() }
        .onChange(of: deepLinkRouter.pendingDestination) { _, pending in
            guard pending != nil, let tab = deepLinkRouter.consumePendingDestination() else { return }
            selectedTab = tab
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

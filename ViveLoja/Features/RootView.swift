import SwiftUI
import UIKit

struct RootView: View {
    @Binding var selectedTab: MainTabView.Tab
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false
    @State private var home = HomeViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isStarting: Bool { session.isRestoring || !home.initialLoadFinished }

    var body: some View {
        @Bindable var session = session
        Group {
            if isStarting { VLLaunchSplash().transition(.opacity) }
            else { MainTabView(selectedTab: $selectedTab, home: home).transition(.opacity) }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isStarting)
        .task(id: session.isRestoring) {
            guard !session.isRestoring, !home.initialLoadFinished else { return }
            let model = home
            let token = session.accessToken
            // A disconnected request must not hold the launch screen indefinitely.
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await model.load(accessToken: token) }
                group.addTask { try? await Task.sleep(for: .seconds(12)) }
                await group.next()
                group.cancelAll()
            }
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
    let home: HomeViewModel
    @State private var avatarIcon: UIImage?

    enum Tab: Hashable { case home, explore, saved, messages, account }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(model: home).tabItem { Label("Inicio", systemImage: "house.fill") }.tag(Tab.home)
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

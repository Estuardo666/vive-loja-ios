import SwiftUI
import UIKit

/// Remote notifications need the UIKit callbacks; SwiftUI has no equivalent for
/// `didRegisterForRemoteNotificationsWithDeviceToken`.
@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    /// Assigned by the App before the first callback can arrive.
    static var pushService: PushService?

    nonisolated func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in AppDelegate.pushService?.didRegister(deviceToken: deviceToken) }
    }

    nonisolated func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in AppDelegate.pushService?.didFailToRegister(error: error) }
    }
}

@main
@MainActor
struct ViveLojaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = SessionStore()
    @State private var saved = SavedStore()
    @State private var deepLinkRouter = DeepLinkRouter()
    @State private var push = PushService()
    @State private var theme = ThemeStore()
    /// Lives here, above the .id() below, so rebuilding for a palette change
    /// does not throw the user back to the first tab.
    @State private var selectedTab = MainTabView.Tab.home

    private var uiTestingColorScheme: ColorScheme? {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting-dark") else { return nil }
        return .dark
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(selectedTab: $selectedTab)
                // VLTheme resolves colours from UserDefaults, outside the
                // SwiftUI graph, so rebuild RootView when the palette changes.
                // Kept innermost so the .task below is not re-run by the swap.
                .id(theme.palette)
                .environment(session)
                .environment(saved)
                .environment(deepLinkRouter)
                .environment(push)
                .environment(theme)
                .onOpenURL { deepLinkRouter.handle($0) }
                .task {
                    AppDelegate.pushService = push
                    push.attach(session: session, router: deepLinkRouter)
                    await session.restore()
                    await push.refreshAuthorization()
                }
                // An APNs token that arrived before sign-in belongs to nobody
                // until a session exists, so it is claimed here.
                .onChange(of: session.user?.id) { _, userId in
                    guard userId != nil else { return }
                    Task { await push.syncPendingRegistration() }
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await session.refreshIfNeeded() }
                }
                .preferredColorScheme(uiTestingColorScheme)
        }
    }
}

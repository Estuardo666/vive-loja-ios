import SwiftUI

@main
@MainActor
struct ViveLojaApp: App {
    @State private var session = SessionStore()
    @State private var saved = SavedStore()
    @State private var deepLinkRouter = DeepLinkRouter()
    @State private var theme = ThemeStore()

    private var uiTestingColorScheme: ColorScheme? {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting-dark") else { return nil }
        return .dark
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                // VLTheme resolves colours from UserDefaults, outside the
                // SwiftUI graph, so rebuild RootView when the palette changes.
                // Kept innermost so the .task below is not re-run by the swap.
                .id(theme.palette)
                .environment(session)
                .environment(saved)
                .environment(deepLinkRouter)
                .environment(theme)
                .onOpenURL { deepLinkRouter.handle($0) }
                .task { await session.restore() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await session.refreshIfNeeded() }
                }
                .preferredColorScheme(uiTestingColorScheme)
        }
    }
}

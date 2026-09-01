import SwiftUI

@main
@MainActor
struct ViveLojaApp: App {
    @State private var session = SessionStore()
    @State private var saved = SavedStore()
    @State private var deepLinkRouter = DeepLinkRouter()

    private var uiTestingColorScheme: ColorScheme? {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting-dark") else { return nil }
        return .dark
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(saved)
                .environment(deepLinkRouter)
                .onOpenURL { deepLinkRouter.handle($0) }
                .task { await session.restore() }
                .preferredColorScheme(uiTestingColorScheme)
        }
    }
}

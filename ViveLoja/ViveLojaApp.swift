import SwiftUI

@main
@MainActor
struct ViveLojaApp: App {
    @State private var session = SessionStore()
    @State private var saved = SavedStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(saved)
                .task { await session.restore() }
        }
    }
}

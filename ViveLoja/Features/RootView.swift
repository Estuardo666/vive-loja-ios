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
    @State private var selectedTab = Tab.home

    enum Tab: Hashable { case home, explore, saved, messages, account }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView().tabItem { Label("Inicio", systemImage: "house.fill") }.tag(Tab.home)
            ExploreView().tabItem { Label("Explorar", systemImage: "map.fill") }.tag(Tab.explore)
            SavedPlaceholderView().tabItem { Label("Guardados", systemImage: "heart.fill") }.tag(Tab.saved)
            MessagesPlaceholderView().tabItem { Label("Mensajes", systemImage: "message.fill") }.tag(Tab.messages)
            AccountView().tabItem { Label("Cuenta", systemImage: "person.crop.circle") }.tag(Tab.account)
        }
    }
}

struct SavedPlaceholderView: View { var body: some View { ContentUnavailableView("Aún no hay guardados", systemImage: "heart", description: Text("Guarda locales y eventos para encontrarlos aquí.")) } }
struct MessagesPlaceholderView: View { var body: some View { ContentUnavailableView("Tus mensajes", systemImage: "message", description: Text("Las conversaciones con locales aparecerán aquí.")) } }

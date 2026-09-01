import SwiftUI

struct AccountView: View {
    @Environment(SessionStore.self) private var session
    @State private var showAuth = false

    var body: some View {
        NavigationStack {
            List {
                if let user = session.user {
                    Section {
                        Label(user.name ?? user.email, systemImage: "person.crop.circle.fill").font(.headline)
                        Text(user.email).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Section("Tu actividad") {
                        Label("Mis favoritos", systemImage: "heart")
                        Label("Mis colecciones", systemImage: "folder")
                        Label("Mis reservas", systemImage: "calendar.badge.clock")
                        Label("Mis publicaciones", systemImage: "square.and.pencil")
                    }
                    Section {
                        Button("Cerrar sesión", role: .destructive) { session.signOut() }
                    }
                } else {
                    Section {
                        Button("Inicia sesión o regístrate") { showAuth = true }
                        Text("Guarda lugares, recibe recomendaciones y publica en Loja.").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Cuenta")
            .sheet(isPresented: $showAuth) { AuthView() }
        }
    }
}

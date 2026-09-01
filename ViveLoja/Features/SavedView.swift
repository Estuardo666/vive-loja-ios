import SwiftUI

struct SavedView: View {
    @Environment(SavedStore.self) private var saved
    @Environment(SessionStore.self) private var session
    private let fixtures = HomeViewModel.fixtures

    var body: some View {
        NavigationStack {
            Group {
                if fixtures.filter({ saved.contains($0) }).isEmpty {
                    ContentUnavailableView("Aún no hay guardados", systemImage: "heart", description: Text("Guarda locales y eventos para encontrarlos aquí."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(fixtures.filter({ saved.contains($0) })) { item in
                                NavigationLink(destination: ItemDetailView(item: item)) {
                                    VLItemCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { Button("Quitar de guardados", systemImage: "heart.slash") { saved.toggle(item, accessToken: session.accessToken) } }
                            }
                        }.padding(16)
                    }
                }
            }
        .navigationTitle("Guardados")
        .task {
            if let token = session.accessToken { await saved.sync(accessToken: token) }
        }
        }
    }
}

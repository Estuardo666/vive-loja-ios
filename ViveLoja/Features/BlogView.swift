import Observation
import SwiftUI

@MainActor
@Observable
final class BlogViewModel {
    var posts: [MobilePost] = []
    var isLoading = false
    var errorMessage: String?

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload: ContentPayload = try await APIClient.shared.get("/content")
            posts = payload.posts
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el blog."
        }
    }
}

struct BlogView: View {
    @State private var model = BlogViewModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 20) }
                ForEach(model.posts) { post in
                    VStack(alignment: .leading, spacing: 10) {
                        VLAsyncImage(url: post.image, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(post.title).font(.headline)
                        if let excerpt = post.excerpt { Text(excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                        if let category = post.category { Text(category.name).font(.caption.weight(.semibold)).foregroundStyle(VLTheme.indigo) }
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                if let error = model.errorMessage { ContentUnavailableView("No se pudo actualizar", systemImage: "wifi.exclamationmark", description: Text(error)) }
                if !model.isLoading && model.posts.isEmpty && model.errorMessage == nil {
                    ContentUnavailableView("Aún no hay historias", systemImage: "text.book.closed", description: Text("Vuelve pronto para descubrir Loja."))
                }
            }
            .padding(16)
        }
        .navigationTitle("Historias de Loja")
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

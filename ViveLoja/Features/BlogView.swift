import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class BlogViewModel {
    var posts: [MobilePost] = []
    var promotions: [MobilePromotion] = []
    var routes: [MobileRoute] = []
    var collections: [MobileCollection] = []
    var watchEvents: [MobileWatchEvent] = []
    var isLoading = false
    var isLoadingMore = false
    var canLoadMorePosts = true
    var errorMessage: String?

    func load() async {
        await loadPage(reset: true)
    }

    func loadMore() async {
        guard canLoadMorePosts, !isLoading, !isLoadingMore else { return }
        await loadPage(reset: false)
    }

    private func loadPage(reset: Bool) async {
        if reset { isLoading = true } else { isLoadingMore = true }
        defer {
            if reset { isLoading = false } else { isLoadingMore = false }
        }
        errorMessage = nil
        let skip = reset ? 0 : posts.count
        do {
            let payload: ContentPayload = try await APIClient.shared.get(
                "/content",
                query: [URLQueryItem(name: "limit", value: "12"), URLQueryItem(name: "postSkip", value: String(skip))]
            )
            if reset { posts = payload.posts } else { posts.append(contentsOf: payload.posts) }
            promotions = payload.promotions
            routes = payload.routes
            collections = payload.collections
            watchEvents = payload.watchEvents
            canLoadMorePosts = payload.posts.count == 12
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "No se pudo cargar el blog."
        }
    }
}

struct ContentHubView: View {
    @State private var model = BlogViewModel()
    @State private var selectedPost: MobilePost?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                if model.isLoading && model.posts.isEmpty && model.promotions.isEmpty && model.routes.isEmpty && model.collections.isEmpty && model.watchEvents.isEmpty {
                    ProgressView("Cargando contenido…").frame(maxWidth: .infinity).padding(.top, 20)
                }
                contentSection("Historias", icon: "text.book.closed.fill") {
                    ForEach(Array(model.posts.prefix(6))) { post in
                        Button {
                            selectedPost = post
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                VLAsyncImage(url: post.image, height: 130)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                Text(post.title).font(.headline)
                                if let excerpt = post.excerpt { Text(excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("post-card")
                        .accessibilityHint("Abre el artículo")
                    }
                }
                if model.canLoadMorePosts && !model.posts.isEmpty {
                    Button {
                        Task { await model.loadMore() }
                    } label: {
                        if model.isLoadingMore { ProgressView() }
                        else { Label("Cargar más historias", systemImage: "arrow.down.circle") }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .tint(VLTheme.indigo)
                }
                contentSection("Promociones activas", icon: "tag.fill") {
                    ForEach(model.promotions) { promotion in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(promotion.title).font(.headline)
                            Text(promotion.venue.name).font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.coral)
                            Text(promotion.description).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                            if let discount = promotion.discount { Label(discount, systemImage: "sparkles").font(.caption.weight(.semibold)) }
                        }
                        .padding(14)
                        .vlGlass(tint: VLTheme.coral.opacity(0.1))
                    }
                }
                contentSection("Rutas para descubrir", icon: "figure.hiking") {
                    ForEach(model.routes) { route in
                        HStack(spacing: 12) {
                            Image(systemName: "map.fill").font(.title2).foregroundStyle(VLTheme.emerald)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(route.title).font(.headline)
                                Text([route.duration, route.difficulty].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(route.stops.count) paradas").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .vlGlass(tint: VLTheme.emerald.opacity(0.1))
                    }
                }
                contentSection("Colecciones de la comunidad", icon: "square.stack.3d.up.fill") {
                    ForEach(model.collections) { collection in
                        HStack(spacing: 12) {
                            Text(collection.icon ?? "✨").font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(collection.name).font(.headline)
                                Text("\(collection.itemCount) guardados")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                contentSection("Transmisiones en vivo", icon: "play.tv.fill") {
                    ForEach(model.watchEvents) { event in
                        NavigationLink(destination: WatchEventDetailView(event: event)) {
                            HStack(spacing: 12) {
                                VLAsyncImage(url: event.image, height: 64).frame(width: 92)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.name).font(.headline).lineLimit(2)
                                    Text(event.matchDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption).foregroundStyle(.secondary)
                                    if let competition = event.competition { Text(competition).font(.caption2).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !model.isLoading && model.posts.isEmpty && model.promotions.isEmpty && model.routes.isEmpty && model.collections.isEmpty && model.watchEvents.isEmpty && model.errorMessage == nil {
                    ContentUnavailableView("Aún no hay contenido", systemImage: "sparkles", description: Text("Vuelve pronto para descubrir Loja."))
                }
                if let error = model.errorMessage {
                    ContentUnavailableView("Sin conexión", systemImage: "wifi.exclamationmark", description: Text(error))
                }
            }
            .padding(16)
        }
        .vlArticleSheet(post: $selectedPost)
        .navigationTitle("Descubre Loja")
        .refreshable { await model.load() }
        .task { if !isUITesting { await model.load() } }
    }

    @ViewBuilder
    private func contentSection<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        if !contentIsEmpty(title) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon).font(.title2.weight(.semibold))
                content()
            }
        }
    }

    private func contentIsEmpty(_ title: String) -> Bool {
        switch title {
        case "Historias": return model.posts.isEmpty
        case "Promociones activas": return model.promotions.isEmpty
        case "Rutas para descubrir": return model.routes.isEmpty
        case "Colecciones de la comunidad": return model.collections.isEmpty
        case "Transmisiones en vivo": return model.watchEvents.isEmpty
        default: return true
        }
    }

    private var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }
}

struct BlogView: View {
    @State private var model = BlogViewModel()
    @State private var selectedPost: MobilePost?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                if model.isLoading { ProgressView().padding(.top, 20) }
                ForEach(model.posts) { post in
                    Button {
                        selectedPost = post
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            VLAsyncImage(url: post.image, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            Text(post.title).font(.headline)
                            if let excerpt = post.excerpt { Text(excerpt).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                            if let category = post.category { Text(category.name).font(.caption.weight(.semibold)).foregroundStyle(VLTheme.indigo) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("post-card")
                    .accessibilityHint("Abre el artículo")
                }
                if let error = model.errorMessage { ContentUnavailableView("No se pudo actualizar", systemImage: "wifi.exclamationmark", description: Text(error)) }
                if !model.isLoading && model.posts.isEmpty && model.errorMessage == nil {
                    ContentUnavailableView("Aún no hay historias", systemImage: "text.book.closed", description: Text("Vuelve pronto para descubrir Loja."))
                }
            }
            .padding(16)
        }
        .vlArticleSheet(post: $selectedPost)
        .navigationTitle("Historias de Loja")
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

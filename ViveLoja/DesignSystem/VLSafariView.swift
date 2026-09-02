import SafariServices
import SwiftUI

/// In-app browser used to read articles.
///
/// The mobile API returns a post's title, excerpt and image but never its
/// body, so there is nothing to render natively. The site already publishes
/// the article at /blog/[slug]; Reader mode strips the site chrome, which
/// gets it close to a native reading view without a new endpoint.
struct VLSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = true
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(VLTheme.indigo)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

extension View {
    /// Presents `post` as an article, or nothing when it is nil.
    func vlArticleSheet(post: Binding<MobilePost?>) -> some View {
        sheet(item: post) { post in
            VLSafariView(url: AppEnvironment.current.articleURL(slug: post.slug))
                .ignoresSafeArea()
        }
    }
}

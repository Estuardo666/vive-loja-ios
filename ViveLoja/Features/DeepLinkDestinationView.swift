import SwiftUI

/// Renders a destination reached through a Universal Link, the `viveloja://`
/// scheme or a push notification tap. Pushed onto a tab's `NavigationStack`
/// (see `DeepLinkRouter`), so the tab bar stays reachable and the screen keeps
/// its place in the back stack.
struct DeepLinkDestinationView: View {
    let destination: DeepLinkRouter.Destination

    var body: some View {
        switch destination {
        case .venue(let slug):
            ItemDetailView(item: .venue(ExploreVenue.placeholder(slug: slug)))
        case .event(let slug):
            ItemDetailView(item: .event(ExploreEvent.placeholder(slug: slug)))
        case .post(let slug):
            // Was BlogView, which dropped the reader on the index instead of
            // the article they tapped.
            VLSafariView(url: AppEnvironment.current.shareURL(for: .post, slug: slug))
                .ignoresSafeArea()
        case .watchEvent(let slug):
            WatchEventDetailView(event: MobileWatchEvent.placeholder(slug: slug))
        case .route(let slug):
            RouteDetailView(slug: slug)
        case .collection(let slug):
            PublicCollectionView(slug: slug)
        }
    }
}

extension MobileWatchEvent {
    static func placeholder(slug: String) -> MobileWatchEvent {
        MobileWatchEvent(id: "deep-link-watch-\(slug)", name: "Cargando…", slug: slug, type: "OTHER", description: nil, image: nil, matchDate: .now, matchTime: nil, competition: nil, performers: [], featured: false, viewCount: 0, venueCount: nil)
    }
}

extension ExploreVenue {
    static func placeholder(slug: String) -> ExploreVenue {
        ExploreVenue(id: "deep-link-venue-\(slug)", name: "Cargando…", slug: slug, description: nil, image: nil, location: nil, address: nil, lat: nil, lng: nil, featured: false, phone: nil, website: nil, priceRange: nil, avgRating: nil, reviewCount: 0, verified: false, categories: [])
    }
}

extension ExploreEvent {
    static func placeholder(slug: String) -> ExploreEvent {
        ExploreEvent(id: "deep-link-event-\(slug)", title: "Cargando…", slug: slug, description: nil, image: nil, startDate: .now, endDate: nil, location: nil, address: nil, lat: nil, lng: nil, featured: false, price: nil, avgRating: nil, reviewCount: 0, categories: [])
    }
}

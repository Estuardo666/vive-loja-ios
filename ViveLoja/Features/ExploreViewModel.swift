import CoreLocation
import MapKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ExploreViewModel {
    var query = ""
    var type = "all"
    var minRating: Double?
    var openNow = false
    var verified = false
    var hasPromotions = false
    var hasUpcomingEvents = false
    var priceRange: String?
    var services: [String] = []
    var foodTypes: [String] = []
    var eventDatePreset: String?
    var eventPrice: String?
    var eventMaxPrice: Double?
    var eventType: String?
    var categorySlugs: [String] = []
    var categories: [Category] = []
    var items: [ExploreItem] = HomeViewModel.fixtures
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    /// Paging cursors returned by the backend. Nil means "nothing loaded yet",
    /// so the list is showing fixtures rather than a finished page.
    private(set) var pageInfo: ExplorePageInfo?
    /// Repeated so "load more" keeps the same search area as the first page.
    private var lastCenter: CLLocationCoordinate2D?
    private var lastRadiusMeters: CLLocationDistance?

    private static let pageSize = 60

    var canLoadMore: Bool {
        guard let pageInfo else { return false }
        return pageInfo.hasMoreVenues || pageInfo.hasMoreEvents
    }

    func search(center: CLLocationCoordinate2D? = nil, radiusMeters: CLLocationDistance? = nil) async {
        isLoading = true
        defer { isLoading = false }
        lastCenter = center
        lastRadiusMeters = radiusMeters
        let queryItems = buildQuery(center: center, radiusMeters: radiusMeters, venueSkip: 0, eventSkip: 0)
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            items = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
            pageInfo = payload.pageInfo
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }

    /// Next page of the current search. The skips come from the backend, which
    /// counts rows read rather than rows returned, so filtered pages do not repeat.
    func loadMore() async {
        guard !isLoading, !isLoadingMore, let pageInfo, canLoadMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        let queryItems = buildQuery(
            center: lastCenter,
            radiusMeters: lastRadiusMeters,
            venueSkip: pageInfo.nextVenueSkip,
            eventSkip: pageInfo.nextEventSkip
        )
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            let existing = Set(items.map(\.id))
            let incoming = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
            items += incoming.filter { !existing.contains($0.id) }
            self.pageInfo = payload.pageInfo
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
    }

    private func buildQuery(
        center: CLLocationCoordinate2D?,
        radiusMeters: CLLocationDistance?,
        venueSkip: Int,
        eventSkip: Int
    ) -> [URLQueryItem] {
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: type),
            URLQueryItem(name: "take", value: String(Self.pageSize)),
            URLQueryItem(name: "venueSkip", value: String(venueSkip)),
            URLQueryItem(name: "eventSkip", value: String(eventSkip)),
        ]
        if let minRating { queryItems.append(URLQueryItem(name: "minRating", value: String(minRating))) }
        if openNow { queryItems.append(URLQueryItem(name: "openNow", value: "true")) }
        if verified { queryItems.append(URLQueryItem(name: "verified", value: "true")) }
        if hasPromotions { queryItems.append(URLQueryItem(name: "hasPromotions", value: "true")) }
        if hasUpcomingEvents { queryItems.append(URLQueryItem(name: "hasUpcomingEvents", value: "true")) }
        if let priceRange { queryItems.append(URLQueryItem(name: "priceRange", value: priceRange)) }
        if !services.isEmpty { queryItems.append(URLQueryItem(name: "services", value: services.joined(separator: ","))) }
        if !foodTypes.isEmpty { queryItems.append(URLQueryItem(name: "foodTypes", value: foodTypes.joined(separator: ","))) }
        if let eventDatePreset { queryItems.append(URLQueryItem(name: "eventDatePreset", value: eventDatePreset)) }
        if let eventPrice { queryItems.append(URLQueryItem(name: "eventPrice", value: eventPrice)) }
        if let eventMaxPrice { queryItems.append(URLQueryItem(name: "eventMaxPrice", value: String(eventMaxPrice))) }
        if let eventType { queryItems.append(URLQueryItem(name: "eventType", value: eventType)) }
        if !categorySlugs.isEmpty { queryItems.append(URLQueryItem(name: "category", value: categorySlugs.joined(separator: ","))) }
        if let center, let radiusMeters {
            queryItems += [
                URLQueryItem(name: "lat", value: String(center.latitude)),
                URLQueryItem(name: "lng", value: String(center.longitude)),
                URLQueryItem(name: "radius", value: String(radiusMeters)),
            ]
        }
        queryItems.removeAll { $0.value?.isEmpty == true }
        return queryItems
    }

    /// Chips shown as quick filters. Ordered by what a city guide gets asked for
    /// most; anything the backend does not have is simply skipped.
    private static let preferredQuickSlugs = [
        "gastronomia", "conciertos", "cultura", "deportes",
        "alojamiento", "compras", "belleza", "salud-y-bienestar",
    ]

    var quickCategories: [Category] {
        var picked = Self.preferredQuickSlugs.compactMap { slug in
            categories.first { $0.slug == slug }
        }
        for category in categories where picked.count < 8 && !picked.contains(where: { $0.id == category.id }) {
            picked.append(category)
        }
        return picked
    }

    func toggleQuickCategory(_ slug: String) {
        if let index = categorySlugs.firstIndex(of: slug) {
            categorySlugs.remove(at: index)
        } else {
            categorySlugs.append(slug)
        }
    }

    /// Date shortcuts for the agenda. The backend already accepted
    /// `eventDatePreset` and the filter sheet already had a picker for it; the
    /// values were just never reachable in one tap from the map.
    enum DatePreset: String, CaseIterable, Identifiable {
        case today
        case tomorrow
        case thisWeekend = "thisWeekend"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .today: return "Hoy"
            case .tomorrow: return "Mañana"
            case .thisWeekend: return "Fin de semana"
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .tomorrow: return "sunrise"
            case .thisWeekend: return "calendar"
            }
        }
    }

    /// Selecting a date shortcut implies looking for events, so the type filter
    /// follows; clearing it puts the search back to everything. `type` carries
    /// the sentinel "all" rather than being optional.
    func toggleDatePreset(_ preset: DatePreset) {
        if eventDatePreset == preset.rawValue {
            eventDatePreset = nil
            if type == "event" { type = "all" }
        } else {
            eventDatePreset = preset.rawValue
            type = "event"
        }
    }

    func isDatePresetActive(_ preset: DatePreset) -> Bool {
        eventDatePreset == preset.rawValue
    }

    func loadCategories() async {
        guard categories.isEmpty else { return }
        if let payload: HomePayload = try? await APIClient.shared.get("/home") { categories = payload.categories }
    }

    var activeFilterCount: Int {
        [minRating != nil, openNow, verified, hasPromotions, hasUpcomingEvents, priceRange != nil, !categorySlugs.isEmpty,
         !services.isEmpty, !foodTypes.isEmpty, eventDatePreset != nil, eventPrice != nil,
         eventMaxPrice != nil, eventType != nil].filter { $0 }.count
    }

    func resetFilters() {
        minRating = nil; openNow = false; verified = false; hasPromotions = false; hasUpcomingEvents = false
        priceRange = nil; services = []; foodTypes = []; eventDatePreset = nil; eventPrice = nil; categorySlugs = []
        eventMaxPrice = nil; eventType = nil
    }
}

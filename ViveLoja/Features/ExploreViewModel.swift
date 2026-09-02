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
    var errorMessage: String?

    func search(center: CLLocationCoordinate2D? = nil, radiusMeters: CLLocationDistance? = nil) async {
        isLoading = true
        defer { isLoading = false }
        var queryItems = [URLQueryItem(name: "q", value: query), URLQueryItem(name: "type", value: type), URLQueryItem(name: "take", value: "60")]
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
        do {
            let payload: ExplorePayload = try await APIClient.shared.get("/explore", query: queryItems)
            items = payload.venues.map(ExploreItem.venue) + payload.events.map(ExploreItem.event)
        } catch { errorMessage = (error as? LocalizedError)?.errorDescription }
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

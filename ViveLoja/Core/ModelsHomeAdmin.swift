import Foundation

/// Admin-side model of the home composition, used by the in-app editor.
///
/// `HomeSection` (the read model) carries resolved items for rendering; this one
/// carries the configuration behind them. They stay separate because an editor
/// needs the filters, and the home screen must never see them.

/// Every parameter any section type accepts, all optional.
///
/// A single flat struct keeps the round-trip lossless: the editor sends back the
/// keys it did not touch (a curated `manual` list, say) exactly as it received
/// them, and the backend still validates them against the section's type.
struct HomeSectionParams: Codable, Hashable, Sendable {
    struct ManualItem: Codable, Hashable, Sendable {
        let kind: String
        let id: String
    }

    var limit: Int?
    var categorySlug: String?
    var featured: Bool?
    var verified: Bool?
    var hasPromotion: Bool?
    var sort: String?
    var dateRange: String?
    var kind: String?
    var window: String?
    var slug: String?
    var tagSlug: String?
    var categorySlugs: [String]?
    var items: [ManualItem]?
    var body: String?
    var ctaLabel: String?
    var ctaDeeplink: String?
    var imageUrl: String?

    init() {}
}

struct HomeSectionAdmin: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var type: String
    var title: String
    var subtitle: String?
    var actionLabel: String?
    var layout: String
    var params: HomeSectionParams
    var order: Int
    var isActive: Bool
    var platform: String

    var typeLabel: String { HomeSectionCatalog.label(forType: type) }
    var layoutLabel: String { HomeSectionCatalog.label(forLayout: layout) }
}

/// Body of a create/update request. `type` is always sent so the backend can
/// validate `params` against the right shape.
struct HomeSectionAdminRequest: Codable, Sendable {
    let type: String
    let title: String
    let subtitle: String?
    let actionLabel: String?
    let layout: String
    let platform: String
    let isActive: Bool
    let params: HomeSectionParams
}

struct HomeSectionListResponse: Codable, Sendable {
    let sections: [HomeSectionAdmin]
}

struct HomeSectionResponse: Codable, Sendable {
    let section: HomeSectionAdmin
}

struct HomeSectionReorderRequest: Codable, Sendable {
    let ids: [String]
}

struct HomeSectionToggleRequest: Codable, Sendable {
    let isActive: Bool
}

/// Names shown in the editor. Kept in one place so the picker, the list and the
/// summaries agree, and so an unknown type coming from a newer backend still
/// shows something readable instead of blank.
enum HomeSectionCatalog {
    static let types: [(value: String, label: String)] = [
        ("hero", "Hero"),
        ("todayInLoja", "Hoy en Loja"),
        ("categoryChips", "Chips de categoría"),
        ("venueList", "Locales"),
        ("openNow", "Abiertos ahora"),
        ("eventList", "Eventos"),
        ("ranked", "Top / Ranking"),
        ("collection", "Colección"),
        ("promotions", "Promociones"),
        ("posts", "Blog"),
        ("routes", "Rutas"),
        ("manual", "Selección manual")
    ]

    static let layouts: [(value: String, label: String)] = [
        ("hero", "Hero"),
        ("chips", "Chips"),
        ("carousel", "Carrusel"),
        ("ranked", "Ranking numerado"),
        ("grid", "Cuadrícula"),
        ("list", "Lista")
    ]

    static let platforms: [(value: String, label: String)] = [
        ("all", "App y web"),
        ("ios", "Solo app"),
        ("web", "Solo web")
    ]

    static let venueSorts: [(value: String, label: String)] = [
        ("recent", "Más recientes"),
        ("popular", "Más vistos"),
        ("rating", "Mejor valorados"),
        ("featured", "Destacados primero")
    ]

    static let eventSorts: [(value: String, label: String)] = [
        ("soon", "Próximos"),
        ("recent", "Más recientes"),
        ("popular", "Más vistos"),
        ("featured", "Destacados primero")
    ]

    static let dateRanges: [(value: String, label: String)] = [
        ("all", "Sin límite"),
        ("today", "Hoy"),
        ("week", "Esta semana"),
        ("month", "Este mes")
    ]

    static func defaultLayout(forType type: String) -> String {
        switch type {
        case "hero": return "hero"
        case "categoryChips": return "chips"
        case "ranked": return "ranked"
        case "todayInLoja", "posts": return "list"
        default: return "carousel"
        }
    }

    static func label(forType type: String) -> String {
        types.first { $0.value == type }?.label ?? type
    }

    static func label(forLayout layout: String) -> String {
        layouts.first { $0.value == layout }?.label ?? layout
    }
}

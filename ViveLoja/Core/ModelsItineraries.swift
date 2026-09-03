import Foundation

// Itinerary routes and the venue summary their stops point at. Split out of
// Models.swift, which had grown past the linter's file length limit.

struct MobileRouteStop: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let notes: String?
    let duration: String?
    /// 1-based day of the itinerary. Absent on payloads produced before
    /// multi-day routes existed, where every stop belongs to day 1.
    let day: Int
    let order: Int
    /// "HH:mm" in America/Guayaquil.
    let startTime: String?
    let lat: Double?
    let lng: Double?
    let image: URL?
    /// Estimated travel time from the previous stop.
    let travelMinutes: Int?
    let venue: MobileVenueShort?

    enum CodingKeys: String, CodingKey {
        case id, title, notes, duration, day, order, startTime, lat, lng, image, travelMinutes, venue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        day = try container.decodeIfPresent(Int.self, forKey: .day) ?? 1
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        startTime = try container.decodeIfPresent(String.self, forKey: .startTime)
        lat = try container.decodeIfPresent(Double.self, forKey: .lat)
        lng = try container.decodeIfPresent(Double.self, forKey: .lng)
        image = try container.decodeIfPresent(URL.self, forKey: .image)
        travelMinutes = try container.decodeIfPresent(Int.self, forKey: .travelMinutes)
        venue = try container.decodeIfPresent(MobileVenueShort.self, forKey: .venue)
    }

    init(
        id: String,
        title: String,
        notes: String? = nil,
        duration: String? = nil,
        day: Int = 1,
        order: Int = 0,
        startTime: String? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        image: URL? = nil,
        travelMinutes: Int? = nil,
        venue: MobileVenueShort? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.duration = duration
        self.day = day
        self.order = order
        self.startTime = startTime
        self.lat = lat
        self.lng = lng
        self.image = image
        self.travelMinutes = travelMinutes
        self.venue = venue
    }

    /// Coordinate of the stop itself, falling back to the venue it points at.
    var coordinate: (lat: Double, lng: Double)? {
        if let lat, let lng { return (lat, lng) }
        if let venueLat = venue?.lat, let venueLng = venue?.lng { return (venueLat, venueLng) }
        return nil
    }
}

struct MobileVenueShort: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let image: URL?
    let lat: Double?
    let lng: Double?
    let location: String?

    init(
        id: String,
        name: String,
        slug: String,
        image: URL? = nil,
        lat: Double? = nil,
        lng: Double? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.image = image
        self.lat = lat
        self.lng = lng
        self.location = location
    }
}

/// One day of an itinerary. The backend emits an entry for every day from 1 to
/// `days`, including empty ones, so the day picker never renumbers.
struct MobileRouteDay: Codable, Identifiable, Hashable, Sendable {
    let day: Int
    let stops: [MobileRouteStop]

    var id: Int { day }
}

struct MobileRoute: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let image: URL?
    let duration: String?
    let difficulty: String?
    let type: String
    let featured: Bool
    let days: Int
    let distanceMeters: Int?
    let estimatedMinutes: Int?
    let stops: [MobileRouteStop]
    /// `/routes` returns `stopCount` without the stops; `/content` returns the
    /// stops themselves. Both decode into this one summary type.
    let stopCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, slug, description, image, duration, difficulty, type, featured, days
        case distanceMeters, estimatedMinutes, stops, stopCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        slug = try container.decode(String.self, forKey: .slug)
        description = try container.decode(String.self, forKey: .description)
        image = try container.decodeIfPresent(URL.self, forKey: .image)
        duration = try container.decodeIfPresent(String.self, forKey: .duration)
        difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty)
        type = try container.decode(String.self, forKey: .type)
        featured = try container.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        days = try container.decodeIfPresent(Int.self, forKey: .days) ?? 1
        distanceMeters = try container.decodeIfPresent(Int.self, forKey: .distanceMeters)
        estimatedMinutes = try container.decodeIfPresent(Int.self, forKey: .estimatedMinutes)
        let decodedStops = try container.decodeIfPresent([MobileRouteStop].self, forKey: .stops) ?? []
        stops = decodedStops
        stopCount = try container.decodeIfPresent(Int.self, forKey: .stopCount) ?? decodedStops.count
    }
}

/// `/routes/{slug}` - the full itinerary.
struct MobileRouteDetail: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slug: String
    let description: String
    let content: String?
    let image: URL?
    let duration: String?
    let difficulty: String?
    let type: String
    let featured: Bool
    let days: Int
    let distanceMeters: Int?
    let estimatedMinutes: Int?
    let startLat: Double?
    let startLng: Double?
    let favoriteCount: Int
    let author: MobileAuthor?
    let stops: [MobileRouteStop]
    let itinerary: [MobileRouteDay]

    /// Falls back to grouping the flat list, so a payload from a server that
    /// predates `itinerary` still renders a day picker instead of nothing.
    var resolvedItinerary: [MobileRouteDay] {
        guard itinerary.isEmpty else { return itinerary }
        let highest = stops.map(\.day).max() ?? 1
        return (1...max(days, highest, 1)).map { day in
            MobileRouteDay(day: day, stops: stops.filter { $0.day == day })
        }
    }
}

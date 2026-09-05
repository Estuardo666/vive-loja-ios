import SwiftUI

/// Name, place, description and the three things a visitor checks before
/// anything else: the rating, the Google badges and whether the door is open.
///
/// Lives outside `ItemDetailView` so that type stays under the linter's body
/// length limit, the same reason `ItemDetailSections` exists.
struct ItemDetailHeader: View {
    let item: ExploreItem
    let venueDetail: VenueDetail?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Every text claims the full column. The screen used to lay itself
            // out around the action row, which was wider than the display, and
            // the title was clipped on both edges as a result.
            Text(item.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(location)
                .font(.headline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(description)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            ratingRow
            googleBadgeRow
            openStateChip
        }
    }

    /// Google's rating wins over the ViveLoja average when the place has one,
    /// the same precedence the web detail page uses. Showing Google content
    /// obliges us to attribute it, so the row links out to the place.
    @ViewBuilder
    private var ratingRow: some View {
        if let google = googleRating {
            HStack(spacing: 8) {
                VLStarRow(rating: google)
                Text(String(format: "%.1f", google)).font(.subheadline.weight(.semibold))
                if let url = venueDetail?.googleMapsUrl {
                    Link(destination: url) {
                        Text("Google (\(googleReviewCount))")
                            .font(.subheadline).foregroundStyle(VLTheme.indigo)
                    }
                    .accessibilityLabel("Ver \(googleReviewCount) reseñas en Google Maps")
                } else {
                    Text("Google (\(googleReviewCount))").font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let rating = averageRating {
            HStack(spacing: 8) {
                VLStarRow(rating: rating)
                Text(String(format: "%.1f", rating)).font(.subheadline.weight(.semibold))
                Text("ViveLoja (\(reviewCount))").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(String(format: "%.1f de 5, %d reseñas", rating, reviewCount))
        }
    }

    @ViewBuilder
    private var googleBadgeRow: some View {
        let badges = venueDetail?.googleBadges ?? []
        if !badges.isEmpty {
            // At most two of these, so they sit in a plain row rather than in a
            // scroll view that would fight the page's own vertical drag.
            HStack(spacing: 8) {
                ForEach(badges) { badge in
                    Text("\(badge.icon)  \(badge.label)")
                        .font(.caption.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(VLTheme.indigo.opacity(0.14), in: Capsule())
                        .foregroundStyle(VLTheme.indigo)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "Abierto ahora · Cierra a las 24:00" up here, next to the name, rather
    /// than only down in Horarios — it is the first thing a visitor checks.
    @ViewBuilder
    private var openStateChip: some View {
        if let openState = venueDetail?.openState {
            Label(openState.detailLabel, systemImage: openState.isOpen ? "clock.badge.checkmark" : "clock.badge.xmark")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background((openState.isOpen ? Color.green : Color.secondary).opacity(0.16), in: Capsule())
                .foregroundStyle(openState.isOpen ? Color.green : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var googleRating: Double? {
        guard let rating = venueDetail?.googleRating, rating > 0 else { return nil }
        return rating
    }

    private var googleReviewCount: Int { venueDetail?.googleReviewCount ?? 0 }

    private var location: String {
        switch item {
        case .venue(let value): return value.location ?? "Loja"
        case .event(let value): return value.location ?? "Loja"
        }
    }

    private var description: String {
        switch item {
        case .venue(let value): return value.description ?? "Descubre este lugar en Loja."
        case .event(let value): return value.description ?? "Un evento para vivir Loja."
        }
    }

    private var averageRating: Double? {
        switch item {
        case .venue(let value): return value.avgRating
        case .event(let value): return value.avgRating
        }
    }

    private var reviewCount: Int {
        switch item {
        case .venue(let value): return value.reviewCount
        case .event(let value): return value.reviewCount
        }
    }
}

/// Opening hours, with the server-resolved state as the section's own summary.
struct VenueHoursSection: View {
    let venueDetail: VenueDetail?

    var body: some View {
        if !businessHours.isEmpty || venueDetail?.operatingHours != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Horarios").font(.title2.weight(.semibold))
                    Spacer()
                    // Estado resuelto en el servidor con la hora de Loja (feriados incluidos).
                    if let openState = venueDetail?.openState {
                        Label(openState.label, systemImage: openState.isOpen ? "clock.badge.checkmark" : "clock.badge.xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(openState.isOpen ? Color.green : Color.secondary)
                    }
                }
                if !businessHours.isEmpty {
                    ForEach(businessHours) { hours in
                        HStack {
                            Text(Self.dayName(hours.dayOfWeek)).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(hours.isClosed ? "Cerrado" : "\(hours.openTime) – \(hours.closeTime)")
                                .font(.subheadline).foregroundStyle(hours.isClosed ? .secondary : .primary)
                        }
                    }
                } else if let legacy = venueDetail?.operatingHours {
                    ForEach(Array(Self.legacyDays(legacy).enumerated()), id: \.offset) { entry in
                        let day = entry.element.0
                        let schedule = entry.element.1
                        HStack {
                            Text(day).font(.subheadline.weight(.semibold))
                            Spacer()
                            Text(schedule ?? "Cerrado").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    if let notes = legacy.notes, !notes.isEmpty {
                        Text(notes).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var businessHours: [MobileBusinessHours] { venueDetail?.businessHours ?? [] }

    static func dayName(_ day: Int) -> String {
        ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"].safeValue(at: day) ?? "Día"
    }

    static func legacyDays(_ hours: MobileOperatingHours) -> [(String, String?)] {
        [("Lunes", hours.mon), ("Martes", hours.tue), ("Miércoles", hours.wed), ("Jueves", hours.thu), ("Viernes", hours.fri), ("Sábado", hours.sat), ("Domingo", hours.sun)]
    }
}

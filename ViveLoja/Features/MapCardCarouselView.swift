import SwiftUI

/// Always-on preview rail at the bottom of the explore map.
///
/// This replaces the peek sheet that used to be presented when a pin was
/// tapped. The rail and the map share `selectedID`, so the binding is driven
/// from both directions: swiping the cards selects the matching pin, and
/// tapping a pin scrolls its card into view. Because the two write to the same
/// piece of state, the scroll position is only pushed back to the caller when
/// it actually settles on a different card — otherwise the map's own selection
/// would be overwritten mid-animation by the rail catching up.
struct MapCardCarouselView: View {
    let items: [ExploreItem]
    @Binding var selectedID: String?
    /// Starts in-map guidance for the card in view; the route belongs to the
    /// map, so the caller owns it.
    let onDirections: (ExploreItem) -> Void

    @State private var scrollID: String?
    /// Set while the rail is being positioned by code rather than by a finger,
    /// so parking on a card does not read as the user choosing it.
    @State private var isSyncing = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(items) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        MapPreviewCard(item: item) { onDirections(item) }
                    }
                    .buttonStyle(.plain)
                    .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: 12)
                    .id(item.id)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollID, anchor: .center)
        .scrollClipDisabled()
        .frame(height: MapPreviewCard.height)
        .onAppear { park(on: selectedID ?? items.first?.id) }
        // A new set of results: park on whatever is still selected, or back at
        // the start, without treating either as a fresh choice.
        .onChange(of: items.map(\.id)) { _, ids in
            guard scrollID == nil || !ids.contains(scrollID ?? "") else { return }
            park(on: selectedID.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first)
        }
        // Pin tapped on the map: bring its card in.
        .onChange(of: selectedID) { _, id in
            guard let id, id != scrollID else { return }
            isSyncing = true
            withAnimation(.snappy) { scrollID = id }
        }
        // Card swiped: select its pin. Guarded so the rail settling on the card
        // the map just chose does not re-write the same value.
        .onChange(of: scrollID) { _, id in
            guard !isSyncing else { isSyncing = false; return }
            guard let id, id != selectedID else { return }
            selectedID = id
        }
        .accessibilityIdentifier("explore-card-carousel")
    }

    /// Moves the rail without letting the move count as a selection.
    private func park(on id: String?) {
        guard id != scrollID else { return }
        isSyncing = true
        scrollID = id
    }
}

/// One card in the rail: photo, type badge, title and the line that answers
/// "when" for events and "where" for venues, plus a direct route button.
struct MapPreviewCard: View {
    let item: ExploreItem
    let onDirections: () -> Void

    static let height: CGFloat = 108

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(categoryIcon)  \(isVenue ? "Local" : "Evento")")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(VLTheme.itemColor(item).opacity(0.16), in: Capsule())
                        .foregroundStyle(VLTheme.itemColor(item))
                    Spacer(minLength: 0)
                    if let rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(VLTheme.indigo)
                            .labelStyle(.titleAndIcon)
                    }
                }
                Text(item.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
            if item.coordinate != nil {
                Button {
                    InteractionTracker.directions(item: item)
                    onDirections()
                } label: {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .vlGlass(tint: VLTheme.indigo, radius: 17)
                .foregroundStyle(Color.white)
                .accessibilityIdentifier("map-card-directions")
                .accessibilityLabel("Cómo llegar a \(item.title)")
            }
        }
        .padding(10)
        .frame(height: MapPreviewCard.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(VLTheme.outline) }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        .accessibilityElement(children: .contain)
    }

    /// Same fallback chain the peek card used: venues without an image of their
    /// own are illustrated by their Google photo.
    private var thumbnail: some View {
        Group {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: fallbackThumbnail
                    default: placeholderThumbnail
                    }
                }
            } else {
                fallbackThumbnail
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var fallbackThumbnail: some View {
        if case .venue(let venue) = item {
            VLGoogleVenuePhoto(slug: venue.slug, large: false, height: 88, showsAttribution: false)
        } else {
            placeholderThumbnail
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            VLTheme.itemColor(item).opacity(0.25)
            Image(systemName: isVenue ? "mappin" : "calendar").foregroundStyle(VLTheme.itemColor(item))
        }
    }

    private var isVenue: Bool { if case .venue = item { return true }; return false }

    private var categoryIcon: String {
        switch item {
        case .venue(let value): return value.categories.first?.icon ?? "📍"
        case .event(let value): return value.categories.first?.icon ?? "🎉"
        }
    }

    private var imageURL: URL? {
        switch item {
        case .venue(let value): return value.image
        case .event(let value): return value.image
        }
    }

    private var rating: Double? {
        switch item {
        case .venue(let value): return value.avgRating
        case .event(let value): return value.avgRating
        }
    }

    /// Events lead with their date, venues with where they are.
    private var subtitle: String {
        switch item {
        case .venue(let value): return value.address ?? value.location ?? "Loja"
        case .event(let value):
            return value.startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
        }
    }

    /// The bottom line: price for events, open/closed for venues.
    private var trailing: String? {
        switch item {
        case .venue(let value): return value.openState?.label
        case .event(let value):
            guard let price = value.price else { return nil }
            return price > 0 ? "USD \(String(format: "%.2f", price))" : "Gratis"
        }
    }
}

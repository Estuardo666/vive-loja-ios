import SwiftUI

/// Compact card shown when a map pin is tapped, mirroring the web map popup:
/// type badge, name, date, address and a CTA into the full profile.
struct MapItemPeekView: View {
    let item: ExploreItem
    /// Starts in-map guidance; the caller owns the route because the map does.
    let onDirections: () -> Void
    @State private var showFullProfile = false
    /// Seeded at the height this card actually is, not at a guess. The old
    /// 220pt default was taller than the content, and because the detent set is
    /// re-read rather than re-selected, the sheet kept the empty strip under
    /// the buttons for as long as it stayed open.
    @State private var contentHeight: CGFloat = MapItemPeekView.estimatedHeight
    @State private var detent: PresentationDetent = .height(MapItemPeekView.estimatedHeight)

    /// Thumbnail row + address + button row + the paddings around them.
    static let estimatedHeight: CGFloat = 178

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                thumbnail
                VStack(alignment: .leading, spacing: 6) {
                    badge
                    Text(item.title).font(.headline).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            if let startDate {
                Label(startDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)), systemImage: "calendar")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Label(address, systemImage: "mappin.and.ellipse")
                .font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
            if showsGoogleCredit {
                // The thumbnail's own attribution capsule does not fit at 56pt,
                // so the credit Google requires lives here instead.
                Text("Foto de Google Maps").font(.caption2).foregroundStyle(.tertiary)
            }
            HStack(spacing: 10) {
                if item.coordinate != nil {
                    Button {
                        InteractionTracker.directions(item: item)
                        onDirections()
                    } label: {
                        Label("Cómo llegar", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.subheadline.weight(.semibold))
                            .padding(.vertical, 2)
                    }
                    .buttonStyle(.bordered)
                    .tint(VLTheme.indigo)
                    .accessibilityIdentifier("map-peek-directions")
                }
                Button {
                    showFullProfile = true
                } label: {
                    HStack(spacing: 6) {
                        Text(isVenue ? "Ver local" : "Ver evento").font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(VLTheme.itemColor(item))
                .accessibilityIdentifier("map-peek-open")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            guard abs(height - contentHeight) > 0.5 else { return }
            contentHeight = height
            detent = .height(height)
        }
        // Both the set and the selection move together: offering a new height
        // without selecting it leaves the sheet on the previous one.
        .presentationDetents([.height(contentHeight)], selection: $detent)
        // Presented from the peek itself so the profile opens full screen without
        // racing the sheet's own dismissal.
        .fullScreenCover(isPresented: $showFullProfile) {
            NavigationStack {
                ItemDetailView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button { showFullProfile = false } label: { Image(systemName: "xmark") }
                                .accessibilityLabel("Cerrar")
                        }
                    }
            }
        }
    }

    /// Most venues have no image of their own and are illustrated by their
    /// Google photo, which is what the cards and the detail screen already do.
    /// This card used to call `AsyncImage` straight on `image`, so for those
    /// venues it only ever showed the placeholder. The photo client keeps
    /// results in memory for five minutes, so a pin the user has already seen
    /// on a card opens with the picture already there.
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
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var fallbackThumbnail: some View {
        if case .venue(let venue) = item {
            VLGoogleVenuePhoto(slug: venue.slug, large: false, height: 56, showsAttribution: false)
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

    private var badge: some View {
        Text("\(categoryIcon)  \(isVenue ? "Local" : "Evento")")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 3)
            .background(VLTheme.itemColor(item).opacity(0.16), in: Capsule())
            .foregroundStyle(VLTheme.itemColor(item))
    }

    private var isVenue: Bool { if case .venue = item { return true }; return false }

    private var showsGoogleCredit: Bool { isVenue && imageURL == nil }

    private var imageURL: URL? {
        switch item {
        case .venue(let value): return value.image
        case .event(let value): return value.image
        }
    }

    private var address: String {
        switch item {
        case .venue(let value): return value.address ?? value.location ?? "Loja"
        case .event(let value): return value.address ?? value.location ?? "Loja"
        }
    }

    private var startDate: Date? {
        if case .event(let value) = item { return value.startDate }
        return nil
    }

    private var categoryIcon: String {
        switch item {
        case .venue(let value): return value.categories.first?.icon ?? "📍"
        case .event(let value): return value.categories.first?.icon ?? "🎉"
        }
    }
}

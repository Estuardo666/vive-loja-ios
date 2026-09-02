import SwiftUI

/// Compact card shown when a map pin is tapped, mirroring the web map popup:
/// type badge, name, date, address and a CTA into the full profile.
struct MapItemPeekView: View {
    let item: ExploreItem
    /// Starts in-map guidance; the caller owns the route because the map does.
    let onDirections: () -> Void
    @State private var showFullProfile = false

    /// Detent height for `item`, so the sheet hugs its content instead of
    /// leaving dead space under the CTA. Events carry one extra row.
    static func height(for item: ExploreItem) -> CGFloat {
        if case .event = item { return 208 }
        return 176
    }

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
            HStack(spacing: 10) {
                if item.coordinate != nil {
                    Button(action: onDirections) {
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

    private var thumbnail: some View {
        AsyncImage(url: imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                VLTheme.itemColor(item).opacity(0.25)
                Image(systemName: isVenue ? "mappin" : "calendar").foregroundStyle(VLTheme.itemColor(item))
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

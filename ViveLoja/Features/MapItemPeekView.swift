import SwiftUI

/// Compact card shown when a map pin is tapped, mirroring the web map popup:
/// type badge, name, date, address and a CTA into the full profile.
struct MapItemPeekView: View {
    let item: ExploreItem
    @State private var showFullProfile = false

    /// Detent height for `item`, so the sheet hugs its content instead of
    /// leaving dead space under the CTA. Events carry one extra row.
    static func height(for item: ExploreItem) -> CGFloat {
        if case .event = item { return 238 }
        return 206
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            Button {
                showFullProfile = true
            } label: {
                HStack {
                    Text(isVenue ? "Ver local" : "Ver evento").font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(VLTheme.itemColor(item))
            .accessibilityIdentifier("map-peek-open")
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
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
        .frame(width: 64, height: 64)
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

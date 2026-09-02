import SwiftUI

/// Compact card shown when a map pin is tapped, mirroring the web map popup:
/// type badge, name, date, address and a CTA into the full profile.
struct MapItemPeekView: View {
    let item: ExploreItem

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
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
                NavigationLink {
                    ItemDetailView(item: item)
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
                Spacer(minLength: 0)
            }
            .padding(20)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var thumbnail: some View {
        AsyncImage(url: imageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            ZStack {
                VLTheme.itemColor(item).opacity(0.25)
                Image(systemName: isVenue ? "mappin" : "calendar").foregroundStyle(.white)
            }
        }
        .frame(width: 68, height: 68)
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

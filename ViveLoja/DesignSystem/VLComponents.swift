import SwiftUI

struct VLAsyncImage: View {
    let url: URL?
    let height: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            default: Rectangle().fill(.quaternary).overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: height).clipped()
        .accessibilityLabel("Imagen")
    }
}

struct VLSectionHeader: View {
    let title: String
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.weight(.semibold))
            Spacer()
            if let action {
                Button("Ver todo", action: action).font(.subheadline.weight(.semibold)).foregroundStyle(VLTheme.indigo)
            }
        }
    }
}

struct VLItemCard: View {
    let item: ExploreItem
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch item {
            case .venue(let venue): VLAsyncImage(url: venue.image, height: 150)
            case .event(let event): VLAsyncImage(url: event.image, height: 150)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label(isVenue ? "Local" : "Evento", systemImage: isVenue ? "mappin.and.ellipse" : "calendar")
                        .font(.caption.weight(.semibold)).foregroundStyle(VLTheme.itemColor(item))
                    Spacer()
                    Image(systemName: "heart").foregroundStyle(.secondary)
                }
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                Text(itemSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            }
            .padding(12)
        }
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.quaternary) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(isVenue ? "local" : "evento"), \(itemSubtitle)")
        .accessibilityHint("Toca para ver el detalle")
    }

    private var isVenue: Bool { if case .venue = item { true } else { false } }
    private var itemSubtitle: String {
        switch item {
        case .venue(let value): return value.location ?? "Loja"
        case .event(let value): return value.location ?? "Loja"
        }
    }
}

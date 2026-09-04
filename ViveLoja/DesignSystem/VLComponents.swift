import SwiftUI
import UIKit

struct VLAsyncImage: View {
    let url: URL?
    let height: CGFloat
    var googleVenueSlug: String?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image): image.resizable().scaledToFill()
            case .failure:
                fallback
            case .empty:
                if url == nil { fallback } else { placeholder }
            default: Rectangle().fill(.quaternary).overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            }
        }
        .frame(maxWidth: .infinity).frame(height: height).clipped()
    }

    @ViewBuilder private var fallback: some View {
        if let googleVenueSlug {
            VLGoogleVenuePhoto(slug: googleVenueSlug, large: height >= 250, height: height)
        } else { placeholder }
    }

    private var placeholder: some View {
        Rectangle().fill(.quaternary).overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
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
    @State private var showPhoto = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch item {
            case .venue(let venue): VLAsyncImage(url: venue.image, height: 150, googleVenueSlug: venue.slug)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(itemSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color(uiColor: .label))
                    .fixedSize(horizontal: false, vertical: true)
                if let openState {
                    // Server-computed in Loja time, so it always agrees with the
                    // "abierto ahora" filter.
                    Label(openState.label, systemImage: openState.isOpen ? "clock.badge.checkmark" : "clock.badge.xmark")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(openState.isOpen ? Color.green : Color.secondary)
                }
            }
            .padding(12)
        }
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.quaternary) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.title), \(isVenue ? "local" : "evento"), \(itemSubtitle)\(openState.map { ", \($0.label)" } ?? "")")
        .accessibilityHint("Toca para ver el detalle")
        .accessibilityAction(named: Text("Ver foto y fuente")) { showPhoto = true }
        .sheet(isPresented: $showPhoto) {
            NavigationStack {
                Group {
                    switch item {
                    case .venue(let venue):
                        VLAsyncImage(url: venue.image, height: 250, googleVenueSlug: venue.slug)
                    case .event(let event):
                        VLAsyncImage(url: event.image, height: 250)
                    }
                }
                .navigationTitle("Foto")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Cerrar") { showPhoto = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var isVenue: Bool { if case .venue = item { true } else { false } }
    private var openState: OpenState? {
        switch item {
        case .venue(let value): return value.openState
        case .event: return nil
        }
    }

    private var itemSubtitle: String {
        switch item {
        case .venue(let value): return value.location ?? "Loja"
        case .event(let value): return value.location ?? "Loja"
        }
    }
}

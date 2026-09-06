import SwiftUI

/// Horizontal margin of the home column. Carousels scroll edge to edge and
/// re-apply it as scroll content margins, so a card is never clipped by the
/// page padding when it reaches the edge of the screen.
let homeSectionInset: CGFloat = 20

/// Renders one server-driven home section.
///
/// The view knows layouts, not sections: the backend decides what a row is
/// called, what it contains and in which order, and the app only picks the
/// presentation. Anything it does not recognise is skipped by
/// `HomeSection.isRenderable`, so new backend types are safe for old builds.
struct HomeSectionView: View {
    let section: HomeSection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if section.isRenderable {
            switch section.layout {
            case .hero: heroSection
            case .chips: chipsSection
            case .ranked: rankedSection
            case .grid: gridSection
            case .list: listSection
            case .carousel: carouselSection
            case .unknown: EmptyView()
            }
        }
    }

    // MARK: - Layouts

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.largeTitle.weight(.bold))
                .fontDesign(.rounded)
                .tracking(-1.2)
                .minimumScaleFactor(0.75)
            if let body = section.body ?? section.subtitle {
                Text(body).font(.title3).foregroundStyle(.secondary)
            }
            if let label = section.actionLabel {
                NavigationLink(destination: ExploreView()) {
                    Label(label, systemImage: "map.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(.white)
                        .background(VLTheme.indigo, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .vlGlass(tint: VLTheme.indigo.opacity(0.12), radius: 26)
        .padding(.horizontal, homeSectionInset)
    }

    private var chipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            header.padding(.horizontal, homeSectionInset)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(section.items) { item in
                        HomeCategoryChip(item: item)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, homeSectionInset, for: .scrollContent)
        }
    }

    private var carouselSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            header.padding(.horizontal, homeSectionInset)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(section.items) { item in
                        HomeItemLink(item: item) {
                            HomeItemCard(item: item, width: cardWidth)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, homeSectionInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    /// "Top 10 en Loja": the same card with the position drawn over it.
    private var rankedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            header.padding(.horizontal, homeSectionInset)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                        HomeItemLink(item: item) {
                            HomeItemCard(item: item, rank: index + 1, width: cardWidth)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, homeSectionInset, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private var gridSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(section.items) { item in
                    HomeItemLink(item: item) { HomeItemCard(item: item) }
                }
            }
        }
        .padding(.horizontal, homeSectionInset)
    }

    private var listSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(spacing: 10) {
                ForEach(section.items) { item in
                    HomeItemLink(item: item) { HomeItemRow(item: item) }
                }
            }
        }
        .padding(.horizontal, homeSectionInset)
    }

    // MARK: - Pieces

    @ViewBuilder private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            VLSectionHeader(title: section.title, action: nil)
            if let subtitle = section.subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private var cardWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 300 : 265 }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2)
    }
}

/// Wraps a card in a link when the item has a screen, and leaves it inert when
/// it does not (a category chip has no detail view of its own).
private struct HomeItemLink<Content: View>: View {
    let item: HomeItem
    @ViewBuilder let content: Content

    var body: some View {
        if let destination = item.destination {
            NavigationLink(value: destination) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

/// Fever-style card: square art, badge over the image, then title, meta, price.
///
/// The card takes its width as a value rather than inheriting one. Inside a
/// horizontal scroll view SwiftUI proposes no width at all, and a subview that
/// asks for `.infinity` — the artwork, the rank numeral — answers with its own
/// ideal size instead. An outer `.frame(width:)` only *reports* the card as
/// narrow; the oversized child keeps drawing at full size and spills over the
/// next card. Sizing the art here, and hanging the badge and the numeral off it
/// as overlays so they take part in no layout at all, is what keeps a card
/// inside its own bounds.
struct HomeItemCard: View {
    let item: HomeItem
    var rank: Int?
    /// `nil` in a grid, where the column already constrains the card.
    var width: CGFloat?

    private var artHeight: CGFloat { 200 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            artwork
            Text(item.title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let meta {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let priceLabel = item.priceLabel {
                Text(priceLabel)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .leading)
        // Last line of defence: whatever a subview decides to draw, it stops at
        // the edge of the card.
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(item.destination == nil ? "" : "Toca para ver el detalle")
    }

    private var artwork: some View {
        VLAsyncImage(
            url: item.imageUrl,
            height: artHeight,
            width: width,
            googleVenueSlug: item.kind == .venue ? item.slug : nil,
            compactAttribution: true
        )
        .overlay(alignment: .topLeading) {
            if let badge = item.badge {
                Text(badge)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(badgeColor, in: Capsule())
                    .foregroundStyle(.white)
                    .padding(10)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let rank {
                Text("\(rank)")
                    .font(.system(size: 78, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(radius: 6)
                    .padding(.leading, 6)
                    .accessibilityHidden(true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// "★ 4,6 · Sant Jordi Club · sáb 12 sep" — only the parts that exist.
    private var meta: String? {
        var parts: [String] = []
        if let rank { parts.append("Puesto \(rank)") }
        if let rating = item.rating {
            parts.append("★ \(rating.formatted(.number.precision(.fractionLength(1))))")
        }
        if let name = item.venueName ?? item.subtitle, !name.isEmpty { parts.append(name) }
        if let dateLabel = item.dateLabel { parts.append(dateLabel) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var badgeColor: Color {
        switch item.kind {
        case .promotion: return VLTheme.coral
        case .event: return VLTheme.indigo
        default: return VLTheme.emerald
        }
    }

    private var accessibilityLabel: String {
        [item.badge, item.title, meta, item.priceLabel]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

/// Compact row for list sections (blog, Hoy en Loja).
struct HomeItemRow: View {
    let item: HomeItem

    var body: some View {
        HStack(spacing: 12) {
            VLAsyncImage(url: item.imageUrl, height: 64, width: 64)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline).lineLimit(2)
                if let subtitle = item.subtitle ?? item.dateLabel {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if let priceLabel = item.priceLabel {
                    Text(priceLabel).font(.caption.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
            if item.destination != nil {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(VLTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(VLTheme.outline) }
        .accessibilityElement(children: .combine)
    }
}

/// Category pill under the search bar.
struct HomeCategoryChip: View {
    let item: HomeItem

    var body: some View {
        HStack(spacing: 6) {
            if let icon = item.icon, !icon.isEmpty {
                Text(icon).accessibilityHidden(true)
            }
            Text(item.title).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(VLTheme.surface, in: Capsule())
        .overlay { Capsule().stroke(tint, lineWidth: 1.5) }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Filtrar por categoría")
    }

    private var tint: Color {
        guard let value = item.color?.lowercased() else { return VLTheme.outline }
        if value.contains("coral") || value.contains("red") { return VLTheme.coral }
        if value.contains("green") || value.contains("emerald") { return VLTheme.emerald }
        return VLTheme.indigo
    }
}

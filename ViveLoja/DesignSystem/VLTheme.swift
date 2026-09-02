import SwiftUI

enum VLTheme {
    static let indigo = Color(red: 0.25, green: 0.25, blue: 0.78)
    static let coral = Color(red: 0.94, green: 0.32, blue: 0.31)
    static let emerald = Color(red: 0.10, green: 0.56, blue: 0.38)

    static func itemColor(_ item: ExploreItem) -> Color {
        switch item {
        case .venue: return emerald
        case .event: return coral
        }
    }
}

struct VLGlassModifier: ViewModifier {
    let tint: Color?
    let radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Group {
            if reduceTransparency {
                content
                    .padding(1)
                    .background(Color(uiColor: .secondarySystemBackground), in: shape)
                    .clipShape(shape)
            } else {
                content
                    .padding(1)
                    .glassEffect(.regular.tint(tint), in: shape)
                    .clipShape(shape)
            }
        }
    }
}

/// Coordinates multiple Liquid Glass surfaces so they share one material field
/// and morph together when the surrounding layout changes. When the user asks
/// for reduced transparency we keep the same hierarchy but render solid cards.
struct VLGlassEffectContainer<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if reduceTransparency {
            content
        } else {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        }
    }
}

extension View {
    func vlGlass(tint: Color? = nil, radius: CGFloat = 20) -> some View {
        modifier(VLGlassModifier(tint: tint, radius: radius))
    }
}

import SwiftUI
import UIKit

/// Brand palette shared with the web app. Every colour below was checked against
/// WCAG AA (4.5:1) on both themes' background and surface; the ratio is noted
/// next to each value so future tweaks can be re-checked.
///
/// The raw brand teal (#23D3D3) only reaches 1.85:1 on white, so in the light
/// theme it is a fill colour behind dark text, never a text or icon colour. A
/// darkened teal carries the same identity where contrast is required.
enum VLTheme {
    /// Primary action colour: the web app's `--primary` blue.
    static let indigo = dynamic(light: 0x1450D2, dark: 0x4E81EF)   // 6.76 / 4.74
    /// Events.
    static let coral = dynamic(light: 0xB93E12, dark: 0xFF8A5B)    // 5.58 / 7.50
    /// Venues, in the logo's teal family.
    static let emerald = dynamic(light: 0x0B6E70, dark: 0x23D3D3)  // 6.04 / 9.40

    /// Logo teal, for fills and decoration only.
    static let brand = dynamic(light: 0x23D3D3, dark: 0x23D3D3)
    /// Text and glyphs drawn on top of `brand`.
    static let onBrand = dynamic(light: 0x062E3B, dark: 0x062E3B)  // 7.75 on brand
    /// Logo navy.
    static let navy = dynamic(light: 0x00567C, dark: 0x7FD4EE)

    static let background = dynamic(light: 0xF7FAFB, dark: 0x0B1114)
    static let surface = dynamic(light: 0xFFFFFF, dark: 0x131B20)

    static func itemColor(_ item: ExploreItem) -> Color {
        switch item {
        case .venue: return emerald
        case .event: return coral
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
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

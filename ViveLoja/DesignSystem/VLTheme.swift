import SwiftUI
import UIKit

/// Brand palette, plus a Catppuccin option the user can pick in Cuenta.
///
/// Every value was checked against WCAG AA (4.5:1) on its own theme's
/// background and surface. Catppuccin's Latte accents do not clear that bar as
/// published — its blue lands at 4.34, its teal at 3.31 — because the palette is
/// tuned for syntax highlighting rather than small UI text. The Latte entries
/// here are therefore darkened along the same hue until they reach AA; Mocha is
/// used verbatim, since it clears 7.8:1 or better on every accent.
///
/// The brand teal (#23D3D3) reaches only 1.85:1 on white, so in any light
/// theme it is a fill behind dark text, never a text or icon colour.
enum VLTheme {
    /// Primary action colour.
    /// Brand: the web app's --primary. Catppuccin: blue.
    static var indigo: Color { resolve(brand: (0x1450D2, 0x4E81EF), catppuccin: (0x0B59F4, 0x89B4FA)) }
    /// Events. Brand: coral. Catppuccin: peach.
    static var coral: Color { resolve(brand: (0xB93E12, 0xFF8A5B), catppuccin: (0xB44201, 0xFAB387)) }
    /// Venues. Brand: logo teal family. Catppuccin: teal.
    static var emerald: Color { resolve(brand: (0x0B6E70, 0x23D3D3), catppuccin: (0x127278, 0x94E2D5)) }

    /// Decorative fill only; never a text or icon colour in the light theme.
    static var brand: Color { resolve(brand: (0x23D3D3, 0x23D3D3), catppuccin: (0x12757A, 0x94E2D5)) }
    /// Text drawn on top of `brand`.
    static var onBrand: Color { resolve(brand: (0x062E3B, 0x062E3B), catppuccin: (0xEFF1F5, 0x1E1E2E)) }
    static var navy: Color { resolve(brand: (0x00567C, 0x7FD4EE), catppuccin: (0x7E29EE, 0xCBA6F7)) }

    /// The page behind everything. Catppuccin uses its `base`.
    static var background: Color { resolve(brand: (0xF7FAFB, 0x0B1114), catppuccin: (0xEFF1F5, 0x1E1E2E)) }
    /// Cards and rows sitting on `background`. Catppuccin uses `mantle` in the
    /// light theme and `surface0` in the dark one, which is how the palette is
    /// meant to separate panels from the page. Every accent above clears AA on
    /// this as well as on `background`, and the two stay about 1.1:1 apart —
    /// the same faint separation UIKit gives `secondarySystemBackground`.
    static var surface: Color { resolve(brand: (0xEEF3F5, 0x131B20), catppuccin: (0xE6E9EF, 0x313244)) }

    static func itemColor(_ item: ExploreItem) -> Color {
        switch item {
        case .venue: return emerald
        case .event: return coral
        }
    }

    private static func resolve(brand: (light: UInt32, dark: UInt32), catppuccin: (light: UInt32, dark: UInt32)) -> Color {
        let pair = VLPalette.current == .catppuccin ? catppuccin : brand
        return Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
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
                    .background(VLTheme.surface, in: shape)
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

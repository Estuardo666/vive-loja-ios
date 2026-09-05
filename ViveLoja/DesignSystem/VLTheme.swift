import SwiftUI
import UIKit

/// Semantic colours, resolved from whichever `VLFlavor` pair the user picked in
/// Cuenta → Apariencia.
///
/// Macchiato and Mocha are the published values verbatim; every token below
/// clears WCAG AA on them. Latte and Frappé cannot carry caption-sized UI text
/// as published — Latte's peach is 2.64:1 and its teal 3.31:1 on `base`, and
/// Frappé's accents land between 3.4:1 and 4.5:1 on a card — because the
/// palette is tuned for syntax highlighting. Those two therefore draw from
/// `VLFlavor.latteUI` / `VLFlavor.frappeUI`: the same hues walked to AA, with
/// the surfaces and the text ramp untouched. The picker previews the
/// unmodified flavours.
enum VLTheme {
    // MARK: Accents

    /// Primary action colour. Brand blue / Catppuccin blue.
    static var indigo: Color { resolve(\.blue) }
    /// Events. Catppuccin peach.
    static var coral: Color { resolve(\.peach) }
    /// Venues. Catppuccin teal.
    static var emerald: Color { resolve(\.teal) }
    /// Decorative fill; pair it with `onBrand`, never with body text.
    static var brand: Color { resolve(\.teal) }
    /// Text drawn on top of `brand`.
    static var onBrand: Color { resolve(\.base) }
    static var navy: Color { resolve(\.mauve) }
    static var lavender: Color { resolve(\.lavender) }
    static var danger: Color { resolve(\.red) }
    static var warning: Color { resolve(\.yellow) }
    static var success: Color { resolve(\.green) }

    // MARK: Content

    /// Body copy. This is what was missing before: with the system label colour
    /// the screens stayed black-on-white and no palette could show through.
    static var text: Color { resolve(\.text) }
    /// Secondary copy — captions, detail rows. `subtext1` rather than
    /// `subtext0`: the lighter step drops to 4.37:1 on Latte's `base` and
    /// 4.26:1 on Frappé's `surface0`, both under AA for caption-sized text.
    static var subtext: Color { resolve(\.subtext1) }
    /// Tertiary marks — placeholders, disabled glyphs, unselected controls.
    /// Both steps clear the 3:1 non-text minimum on every flavour and every
    /// background, including a bar; Latte needs `subtext0` to get there, where
    /// `overlay2` falls to 2.99:1 on `crust`. Not for body copy.
    static var muted: Color { resolveSplit(light: \.subtext0, dark: \.overlay2) }

    // MARK: Surfaces

    /// The page behind everything. Catppuccin `base`.
    static var background: Color { resolve(\.base) }
    /// Cards and list rows sitting on `background`. `mantle` in the light
    /// flavour, `surface0` in the dark ones, which is how the palette separates
    /// panels from the page.
    static var surface: Color { resolveSplit(light: \.mantle, dark: \.surface0) }
    /// A step above `surface`: chips, segmented backgrounds, pressed rows.
    /// Not a background for small text — on Frappé it sits within 3.1:1 of the
    /// accents. Text belongs on `background`, `surface` or `chrome`.
    static var surfaceElevated: Color { resolveSplit(light: \.crust, dark: \.surface1) }
    /// Hairlines and card borders.
    static var outline: Color { resolveSplit(light: \.surface1, dark: \.surface1) }
    /// Bars and chrome that sit a step behind `surface`.
    static var chrome: Color { resolveSplit(light: \.crust, dark: \.mantle) }

    // MARK: Map

    /// MapKit has no stylesheet — the platform gives four basemap
    /// configurations and the light/dark appearance, nothing else. To bring the
    /// tiles into the palette we lay this over them in `.color` blend mode,
    /// which rotates their hue without darkening them, so street names stay as
    /// readable as on the untinted map. `nil` on the brand palette, which is
    /// what the stock basemap already looks like.
    static var mapTint: Color? {
        guard VLPalette.current == .catppuccin else { return nil }
        return resolve(\.lavender)
    }

    /// How much of `mapTint` to mix in. Enough to read as the palette, low
    /// enough that labels keep their contrast against the tiles.
    static let mapTintOpacity: Double = 0.22

    static func itemColor(_ item: ExploreItem) -> Color {
        switch item {
        case .venue: return emerald
        case .event: return coral
        }
    }

    // MARK: Resolution

    /// The flavour pair for the current selection, read without actor isolation
    /// so UIKit annotation views can resolve colours too.
    static var pair: (light: VLFlavor, dark: VLFlavor) {
        let variation = VLVariation.current
        return (variation.lightFlavor, variation.darkFlavor)
    }

    static func flavor(for style: UIUserInterfaceStyle) -> VLFlavor {
        let pair = pair
        return style == .dark ? pair.dark : pair.light
    }

    private static func resolve(_ slot: KeyPath<VLFlavor, UInt32>) -> Color {
        resolveSplit(light: slot, dark: slot)
    }

    private static func resolveSplit(
        light: KeyPath<VLFlavor, UInt32>,
        dark: KeyPath<VLFlavor, UInt32>
    ) -> Color {
        Color(uiColor: uiColor(light: light, dark: dark))
    }

    /// UIKit needs the dynamic colour itself, not a SwiftUI wrapper, or the bar
    /// appearances resolve once and stop following the appearance.
    static func uiColor(
        light: KeyPath<VLFlavor, UInt32>,
        dark: KeyPath<VLFlavor, UInt32>
    ) -> UIColor {
        UIColor { traits in
            // The user's Apariencia choice wins over the trait collection,
            // because `preferredColorScheme` does not reach every UIKit view
            // that resolves a dynamic colour.
            let forced = VLAppearance.current.userInterfaceStyle
            let style = forced == .unspecified ? traits.userInterfaceStyle : forced
            let pair = pair
            let isDark = style == .dark
            let flavor = isDark ? pair.dark : pair.light
            return UIColor(rgb: flavor[keyPath: isDark ? dark : light])
        }
    }

    static func uiColor(_ slot: KeyPath<VLFlavor, UInt32>) -> UIColor {
        uiColor(light: slot, dark: slot)
    }
}

extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Screen chrome

/// Lists and scroll views default to the system grouped background, which is
/// the single biggest reason a custom palette still looks like stock iOS. This
/// paints the page and the rows from the palette instead.
struct VLScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(VLTheme.background)
            .listRowBackground(VLTheme.surface)
    }
}

/// Sets the three hierarchical foreground levels from the palette, so plain
/// `Text` and `.secondary` pick up the theme without touching every view.
///
/// With Increase Contrast on, the palette has no darker step to fall back to —
/// the flavours are fixed — so the levels collapse one rung: secondary copy is
/// drawn in `text` and tertiary marks in `subtext`.
struct VLContentStyleModifier: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if contrast == .increased {
            content.foregroundStyle(VLTheme.text, VLTheme.text, VLTheme.subtext)
        } else {
            content.foregroundStyle(VLTheme.text, VLTheme.subtext, VLTheme.muted)
        }
    }
}

extension View {
    /// Apply to the scrollable container of every screen.
    func vlScreen() -> some View { modifier(VLScreenModifier()) }

    func vlContentStyle() -> some View { modifier(VLContentStyleModifier()) }
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

/// UIKit draws the tab bar, the navigation bars, the table sections and the
/// search field, and none of them read a SwiftUI colour. Without this the
/// palette stops at the edge of the content and the chrome stays system grey,
/// which is exactly where the seam shows. Called on launch and whenever the
/// theme changes.
@MainActor
enum VLBarAppearance {
    static func apply() {
        let chrome = VLTheme.uiColor(light: \.crust, dark: \.mantle)
        let text = VLTheme.uiColor(\.text)
        let subtext = VLTheme.uiColor(\.subtext1)
        let accent = VLTheme.uiColor(\.blue)
        let background = VLTheme.uiColor(\.base)
        let separator = VLTheme.uiColor(\.surface1)

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        tab.backgroundColor = chrome
        for item in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            item.normal.iconColor = subtext
            item.normal.titleTextAttributes = [.foregroundColor: subtext]
            item.selected.iconColor = accent
            item.selected.titleTextAttributes = [.foregroundColor: accent]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithDefaultBackground()
        nav.backgroundColor = chrome
        nav.titleTextAttributes = [.foregroundColor: text]
        nav.largeTitleTextAttributes = [.foregroundColor: text]
        nav.shadowColor = separator
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance().withTransparentPage(titleColor: text)
        UINavigationBar.appearance().tintColor = accent

        // Lists, section headers and the search field are UIKit all the way
        // down; these are the ones that kept showing systemGroupedBackground.
        UITableView.appearance().backgroundColor = background
        UITableView.appearance().separatorColor = separator
        UICollectionView.appearance().backgroundColor = background
        UIRefreshControl.appearance().tintColor = accent
        UISwitch.appearance().onTintColor = accent
        UIPageControl.appearance().currentPageIndicatorTintColor = accent
        UIPageControl.appearance().pageIndicatorTintColor = VLTheme.uiColor(\.overlay0)

        let search = UISearchBar.appearance()
        search.tintColor = accent
        search.searchTextField.textColor = text

        // Existing windows keep the appearance they were built with.
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = VLAppearance.current.userInterfaceStyle
                window.tintColor = accent
                window.rootViewController?.view.setNeedsLayout()
            }
        }
    }
}

private extension UINavigationBarAppearance {
    /// The large-title state keeps the progressive-blur header the app already
    /// draws for itself; only the collapsed bar gets the palette background.
    func withTransparentPage(titleColor: UIColor) -> UINavigationBarAppearance {
        configureWithTransparentBackground()
        titleTextAttributes = [.foregroundColor: titleColor]
        largeTitleTextAttributes = [.foregroundColor: titleColor]
        return self
    }
}

import Observation
import SwiftUI
import UIKit

// MARK: - Flavours

/// One complete colour ramp. The Catppuccin flavours below are the published
/// hex values from github.com/catppuccin/catppuccin, copied verbatim so the app
/// reads as the real palette rather than as a tinted system theme.
struct VLFlavor: Sendable {
    let rosewater: UInt32
    let flamingo: UInt32
    let pink: UInt32
    let mauve: UInt32
    let red: UInt32
    let maroon: UInt32
    let peach: UInt32
    let yellow: UInt32
    let green: UInt32
    let teal: UInt32
    let sky: UInt32
    let sapphire: UInt32
    let blue: UInt32
    let lavender: UInt32
    let text: UInt32
    let subtext1: UInt32
    let subtext0: UInt32
    let overlay2: UInt32
    let overlay1: UInt32
    let overlay0: UInt32
    let surface2: UInt32
    let surface1: UInt32
    let surface0: UInt32
    let base: UInt32
    let mantle: UInt32
    let crust: UInt32
    /// Latte is the only light Catppuccin flavour; the rest are drawn for dark.
    let isLight: Bool
}

extension VLFlavor {
    static let latte = VLFlavor(
        rosewater: 0xDC8A78, flamingo: 0xDD7878, pink: 0xEA76CB, mauve: 0x8839EF,
        red: 0xD20F39, maroon: 0xE64553, peach: 0xFE640B, yellow: 0xDF8E1D,
        green: 0x40A02B, teal: 0x179299, sky: 0x04A5E5, sapphire: 0x209FB5,
        blue: 0x1E66F5, lavender: 0x7287FD,
        text: 0x4C4F69, subtext1: 0x5C5F77, subtext0: 0x6C6F85,
        overlay2: 0x7C7F93, overlay1: 0x8C8FA1, overlay0: 0x9CA0B0,
        surface2: 0xACB0BE, surface1: 0xBCC0CC, surface0: 0xCCD0DA,
        base: 0xEFF1F5, mantle: 0xE6E9EF, crust: 0xDCE0E8,
        isLight: true
    )

    /// Latte with its accents darkened along their own hue until each reaches
    /// WCAG AA (4.5:1) on `crust`, the darkest light-flavour background, so an
    /// accent clears AA on the page, on a card, and in a bar.
    ///
    /// Latte as published is a syntax-highlighting palette: peach lands at
    /// 2.64:1 on `base`, teal at 3.31, blue at 4.34. Those are fine for a fill
    /// or a large glyph and unreadable for the caption-sized labels this app
    /// draws with them. Surfaces and text ramps are untouched, and the
    /// unmodified `latte` above is what the picker previews, so the flavour
    /// still looks like Latte — only the accent-as-text case is corrected.
    static let latteUI = VLFlavor(
        rosewater: 0x885549, flamingo: 0x944F4F, pink: 0x93497F, mauve: 0x7F33E3,
        red: 0xC70B33, maroon: 0xB3333E, peach: 0xAA4104, yellow: 0x8C5810,
        green: 0x2B701C, teal: 0x0F6D73, sky: 0x006993, sapphire: 0x146D7D,
        blue: 0x1759DC, lavender: 0x4E5DB1,
        text: 0x4C4F69, subtext1: 0x5C5F77, subtext0: 0x6C6F85,
        overlay2: 0x7C7F93, overlay1: 0x8C8FA1, overlay0: 0x9CA0B0,
        surface2: 0xACB0BE, surface1: 0xBCC0CC, surface0: 0xCCD0DA,
        base: 0xEFF1F5, mantle: 0xE6E9EF, crust: 0xDCE0E8,
        isLight: true
    )

    static let frappe = VLFlavor(
        rosewater: 0xF2D5CF, flamingo: 0xEEBEBE, pink: 0xF4B8E4, mauve: 0xCA9EE6,
        red: 0xE78284, maroon: 0xEA999C, peach: 0xEF9F76, yellow: 0xE5C890,
        green: 0xA6D189, teal: 0x81C8BE, sky: 0x99D1DB, sapphire: 0x85C1DC,
        blue: 0x8CAAEE, lavender: 0xBABBF1,
        text: 0xC6D0F5, subtext1: 0xB5BFE2, subtext0: 0xA5ADCE,
        overlay2: 0x949CBB, overlay1: 0x838BA7, overlay0: 0x737994,
        surface2: 0x626880, surface1: 0x51576D, surface0: 0x414559,
        base: 0x303446, mantle: 0x292C3C, crust: 0x232634,
        isLight: false
    )

    /// Frappé is the lightest dark flavour, so its accents land between 3.6:1
    /// and 4.5:1 on `surface0` — the card background — while the same accents
    /// clear AA comfortably on Macchiato and Mocha. These are walked up in
    /// value until they reach 4.5:1 there; the shift is a few percent and the
    /// flavour still reads as Frappé. Surfaces and text ramp are untouched.
    static let frappeUI = VLFlavor(
        rosewater: 0xF2D5CF, flamingo: 0xEEBEBE, pink: 0xF4B8E4, mauve: 0xCDA3E8,
        red: 0xF09D9F, maroon: 0xEC9FA2, peach: 0xEFA178, yellow: 0xE5C890,
        green: 0xA6D189, teal: 0x81C8BE, sky: 0x99D1DB, sapphire: 0x85C1DC,
        blue: 0x98B3F1, lavender: 0xBABBF1,
        text: 0xC6D0F5, subtext1: 0xB5BFE2, subtext0: 0xA5ADCE,
        overlay2: 0x949CBB, overlay1: 0x838BA7, overlay0: 0x737994,
        surface2: 0x626880, surface1: 0x51576D, surface0: 0x414559,
        base: 0x303446, mantle: 0x292C3C, crust: 0x232634,
        isLight: false
    )

    static let macchiato = VLFlavor(
        rosewater: 0xF4DBD6, flamingo: 0xF0C6C6, pink: 0xF5BDE6, mauve: 0xC6A0F6,
        red: 0xED8796, maroon: 0xEE99A0, peach: 0xF5A97F, yellow: 0xEED49F,
        green: 0xA6DA95, teal: 0x8BD5CA, sky: 0x91D7E3, sapphire: 0x7DC4E4,
        blue: 0x8AADF4, lavender: 0xB7BDF8,
        text: 0xCAD3F5, subtext1: 0xB8C0E0, subtext0: 0xA5ADCB,
        overlay2: 0x939AB7, overlay1: 0x8087A2, overlay0: 0x6E738D,
        surface2: 0x5B6078, surface1: 0x494D64, surface0: 0x363A4F,
        base: 0x24273A, mantle: 0x1E2030, crust: 0x181926,
        isLight: false
    )

    static let mocha = VLFlavor(
        rosewater: 0xF5E0DC, flamingo: 0xF2CDCD, pink: 0xF5C2E7, mauve: 0xCBA6F7,
        red: 0xF38BA8, maroon: 0xEBA0AC, peach: 0xFAB387, yellow: 0xF9E2AF,
        green: 0xA6E3A1, teal: 0x94E2D5, sky: 0x89DCEB, sapphire: 0x74C7EC,
        blue: 0x89B4FA, lavender: 0xB4BEFE,
        text: 0xCDD6F4, subtext1: 0xBAC2DE, subtext0: 0xA6ADC8,
        overlay2: 0x9399B2, overlay1: 0x7F849C, overlay0: 0x6C7086,
        surface2: 0x585B70, surface1: 0x45475A, surface0: 0x313244,
        base: 0x1E1E2E, mantle: 0x181825, crust: 0x11111B,
        isLight: false
    )

    /// The brand ramp expressed in the same slots, so every semantic token in
    /// `VLTheme` resolves the same way for both families.
    static let brandLight = VLFlavor(
        rosewater: 0xB93E12, flamingo: 0xB93E12, pink: 0x9B2C87, mauve: 0x6D28D9,
        red: 0xB4232B, maroon: 0xB4232B, peach: 0xB93E12, yellow: 0x8A5A00,
        green: 0x1B7A46, teal: 0x0B6E70, sky: 0x00567C, sapphire: 0x00567C,
        blue: 0x1450D2, lavender: 0x4E81EF,
        text: 0x0C1A22, subtext1: 0x39505C, subtext0: 0x51686F,
        overlay2: 0x6B8189, overlay1: 0x8399A1, overlay0: 0x9DB0B7,
        surface2: 0xC3D0D5, surface1: 0xD8E1E5, surface0: 0xE4EBEE,
        base: 0xF7FAFB, mantle: 0xEEF3F5, crust: 0xFFFFFF,
        isLight: true
    )

    static let brandDark = VLFlavor(
        rosewater: 0xFF8A5B, flamingo: 0xFF8A5B, pink: 0xF08FD4, mauve: 0xB79BFF,
        red: 0xFF6B6B, maroon: 0xFF6B6B, peach: 0xFF8A5B, yellow: 0xF2C46B,
        green: 0x4ADE9B, teal: 0x23D3D3, sky: 0x7FD4EE, sapphire: 0x7FD4EE,
        blue: 0x4E81EF, lavender: 0x8FB4FF,
        text: 0xEAF3F6, subtext1: 0xBBCCD4, subtext0: 0x9BB0B9,
        overlay2: 0x7E959E, overlay1: 0x647B85, overlay0: 0x4B626C,
        surface2: 0x1D272E, surface1: 0x243038, surface0: 0x131B20,
        base: 0x0B1114, mantle: 0x080D10, crust: 0x05090B,
        isLight: false
    )
}

// MARK: - User selection

/// Theme family. Each ships one or more flavours as `variations`.
enum VLPalette: String, CaseIterable, Identifiable, Sendable {
    case brand
    case catppuccin

    static let storageKey = "vl.palette"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .brand: return "Vive Loja"
        case .catppuccin: return "Catppuccin"
        }
    }

    var detail: String {
        switch self {
        case .brand: return "El azul y el turquesa del logo."
        case .catppuccin: return "La paleta pastel de Catppuccin, con sus cuatro sabores."
        }
    }

    var variations: [VLVariation] {
        switch self {
        case .brand: return [.viveLoja]
        case .catppuccin: return [.latte, .frappe, .macchiato, .mocha]
        }
    }

    static var current: VLPalette {
        VLPalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .brand
    }
}

/// A flavour inside a family. Latte is the light one, so the app pairs it with
/// the selected dark flavour and the same choice works in both appearances.
enum VLVariation: String, CaseIterable, Identifiable, Sendable {
    case viveLoja
    case latte
    case frappe
    case macchiato
    case mocha

    static let storageKey = "vl.variation"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .viveLoja: return "Original"
        case .latte: return "Latte"
        case .frappe: return "Frappé"
        case .macchiato: return "Macchiato"
        case .mocha: return "Mocha"
        }
    }

    var detail: String {
        switch self {
        case .viveLoja: return "La paleta original de la marca."
        case .latte: return "Claro. En modo oscuro se usa Mocha."
        case .frappe: return "Oscuro suave. En modo claro se usa Latte."
        case .macchiato: return "Oscuro medio. En modo claro se usa Latte."
        case .mocha: return "El más oscuro. En modo claro se usa Latte."
        }
    }

    /// The published flavour, unmodified. This is what the picker previews.
    var flavor: VLFlavor {
        switch self {
        case .viveLoja: return .brandLight
        case .latte: return .latte
        case .frappe: return .frappe
        case .macchiato: return .macchiato
        case .mocha: return .mocha
        }
    }

    /// Latte is the only light Catppuccin flavour, so picking it means
    /// "Latte + Mocha"; picking a dark flavour keeps Latte for the light side.
    /// The AA-corrected accents are used for drawing — see `VLFlavor.latteUI`.
    var lightFlavor: VLFlavor {
        switch self {
        case .viveLoja: return .brandLight
        default: return .latteUI
        }
    }

    /// Same idea as `lightFlavor`: the drawing flavour, AA-corrected where the
    /// published one cannot carry UI text (`VLFlavor.frappeUI`).
    var darkFlavor: VLFlavor {
        switch self {
        case .viveLoja: return .brandDark
        case .latte: return .mocha
        case .frappe: return .frappeUI
        case .macchiato: return .macchiato
        case .mocha: return .mocha
        }
    }

    static func current(for palette: VLPalette) -> VLVariation {
        let stored = VLVariation(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "")
        guard let stored, palette.variations.contains(stored) else {
            return palette.variations[0]
        }
        return stored
    }

    static var current: VLVariation { current(for: .current) }
}

/// Light / dark / follow the system.
enum VLAppearance: String, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    static let storageKey = "vl.appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Claro"
        case .dark: return "Oscuro"
        }
    }

    var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// `preferredColorScheme` does not reach the UIKit chrome, so
    /// `VLBarAppearance` and the window override read this instead.
    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }

    static var current: VLAppearance {
        VLAppearance(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .system
    }
}

/// Holds the selection for SwiftUI. The colours themselves read UserDefaults,
/// which is thread-safe; this exists so views re-render when the choice changes.
@MainActor
@Observable
final class ThemeStore {
    var palette: VLPalette {
        didSet {
            UserDefaults.standard.set(palette.rawValue, forKey: VLPalette.storageKey)
            // A flavour from the previous family means nothing here.
            if !palette.variations.contains(variation) { variation = palette.variations[0] }
        }
    }

    var variation: VLVariation {
        didSet { UserDefaults.standard.set(variation.rawValue, forKey: VLVariation.storageKey) }
    }

    var appearance: VLAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: VLAppearance.storageKey) }
    }

    /// Anything that must rebuild when the look changes keys off this.
    var identity: String { "\(palette.rawValue)-\(variation.rawValue)-\(appearance.rawValue)" }

    init() {
        // XCTest reuses the simulator app container between test methods. A
        // theme selected by one test must not change later screenshots or
        // accessibility audits.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            UserDefaults.standard.removeObject(forKey: VLPalette.storageKey)
            UserDefaults.standard.removeObject(forKey: VLVariation.storageKey)
            UserDefaults.standard.removeObject(forKey: VLAppearance.storageKey)
        }
        let palette = VLPalette.current
        self.palette = palette
        self.variation = VLVariation.current(for: palette)
        self.appearance = VLAppearance.current
    }
}

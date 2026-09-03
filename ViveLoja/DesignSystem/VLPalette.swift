import Observation
import SwiftUI

/// Selectable colour palettes.
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
        case .catppuccin: return "Latte de día, Mocha de noche."
        }
    }

    /// Read without actor isolation so `VLTheme` can resolve colours from
    /// wherever they are needed, including UIKit annotation views.
    static var current: VLPalette {
        VLPalette(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .brand
    }
}

/// Holds the selection for SwiftUI. The colours themselves read UserDefaults,
/// which is thread-safe; this exists so views re-render when the choice changes.
@MainActor
@Observable
final class ThemeStore {
    var palette: VLPalette {
        didSet { UserDefaults.standard.set(palette.rawValue, forKey: VLPalette.storageKey) }
    }

    init() {
        // XCTest reuses the simulator app container between test methods. A
        // palette selected by one test must not change later screenshots or
        // accessibility audits.
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
            UserDefaults.standard.removeObject(forKey: VLPalette.storageKey)
        }
        palette = VLPalette.current
    }
}

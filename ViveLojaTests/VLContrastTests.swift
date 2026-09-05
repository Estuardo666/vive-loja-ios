import XCTest
@testable import ViveLoja

/// WCAG contrast for every drawing flavour. The palettes are static tables, so
/// this is decidable without launching the app — and it is what keeps a future
/// "let's use the published Latte accents verbatim" from shipping 2.6:1 text.
final class VLContrastTests: XCTestCase {
    private struct Sample {
        let name: String
        let flavor: VLFlavor
    }

    /// A named colour, so the failure message says which token broke.
    private struct Slot {
        let name: String
        let hex: UInt32
    }

    private struct CorrectionPair {
        let name: String
        let published: VLFlavor
        let corrected: VLFlavor
    }

    /// The flavours the app actually draws with, not the previewed ones.
    private var drawn: [Sample] {
        [
            Sample(name: "latteUI", flavor: .latteUI),
            Sample(name: "frappeUI", flavor: .frappeUI),
            Sample(name: "macchiato", flavor: .macchiato),
            Sample(name: "mocha", flavor: .mocha),
            Sample(name: "brandLight", flavor: .brandLight),
            Sample(name: "brandDark", flavor: .brandDark)
        ]
    }

    // MARK: Tokens under test

    private func backgrounds(_ flavor: VLFlavor) -> [Slot] {
        [
            Slot(name: "background", hex: flavor.base),
            Slot(name: "surface", hex: flavor.isLight ? flavor.mantle : flavor.surface0),
            Slot(name: "chrome", hex: flavor.isLight ? flavor.crust : flavor.mantle)
        ]
    }

    private func textForegrounds(_ flavor: VLFlavor) -> [Slot] {
        [
            Slot(name: "text", hex: flavor.text),
            Slot(name: "subtext", hex: flavor.subtext1),
            Slot(name: "indigo", hex: flavor.blue),
            Slot(name: "coral", hex: flavor.peach),
            Slot(name: "emerald", hex: flavor.teal),
            Slot(name: "navy", hex: flavor.mauve),
            Slot(name: "danger", hex: flavor.red),
            Slot(name: "warning", hex: flavor.yellow),
            Slot(name: "success", hex: flavor.green)
        ]
    }

    // MARK: Tests

    /// 1.4.3 Contrast (Minimum): 4.5:1 for text under 18pt.
    func testTextTokensMeetAAOnEveryBackground() {
        for sample in drawn {
            for background in backgrounds(sample.flavor) {
                for foreground in textForegrounds(sample.flavor) {
                    let ratio = Self.contrastRatio(foreground.hex, background.hex)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        """
                        \(sample.name): \(foreground.name) on \(background.name) \
                        is \(String(format: "%.2f", ratio)):1
                        """
                    )
                }
            }
        }
    }

    /// 1.4.11 Non-text Contrast: 3:1 for meaningful glyphs and control marks.
    /// `muted` draws unselected controls and placeholder glyphs, so it is held
    /// to the non-text bar rather than to AA.
    func testMutedMeetsNonTextMinimum() {
        for sample in drawn {
            let muted = sample.flavor.isLight ? sample.flavor.subtext0 : sample.flavor.overlay2
            for background in backgrounds(sample.flavor) {
                let ratio = Self.contrastRatio(muted, background.hex)
                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    """
                    \(sample.name): muted on \(background.name) \
                    is \(String(format: "%.2f", ratio)):1
                    """
                )
            }
        }
    }

    /// Cards have to stay distinguishable from the page they sit on, which is a
    /// separation the palette makes deliberately faint — this only guards
    /// against a future edit collapsing the two into the same colour.
    func testSurfaceIsDistinctFromBackground() {
        for sample in drawn {
            let surface = sample.flavor.isLight ? sample.flavor.mantle : sample.flavor.surface0
            XCTAssertNotEqual(surface, sample.flavor.base, "\(sample.name): surface == background")
        }
    }

    /// Latte and Frappé ship corrected accents; the correction must not have
    /// drifted off the published hue, or the flavour stops looking like itself.
    func testCorrectedAccentsKeepTheirHue() {
        let pairs = [
            CorrectionPair(name: "latte", published: .latte, corrected: .latteUI),
            CorrectionPair(name: "frappe", published: .frappe, corrected: .frappeUI)
        ]
        let accents: [KeyPath<VLFlavor, UInt32>] = [\.blue, \.peach, \.teal, \.mauve, \.red, \.green]
        for pair in pairs {
            for accent in accents {
                let delta = Self.hueDelta(
                    pair.published[keyPath: accent],
                    pair.corrected[keyPath: accent]
                )
                XCTAssertLessThanOrEqual(delta, 8.0, "\(pair.name): accent hue moved \(delta)°")
            }
            // The surfaces and the text ramp are never touched.
            XCTAssertEqual(pair.published.base, pair.corrected.base, "\(pair.name): base changed")
            XCTAssertEqual(pair.published.mantle, pair.corrected.mantle, "\(pair.name): mantle changed")
            XCTAssertEqual(pair.published.crust, pair.corrected.crust, "\(pair.name): crust changed")
            XCTAssertEqual(pair.published.text, pair.corrected.text, "\(pair.name): text changed")
            XCTAssertEqual(
                pair.published.subtext1,
                pair.corrected.subtext1,
                "\(pair.name): subtext1 changed"
            )
        }
    }

    // MARK: Colour maths

    private struct Channels {
        let red: Double
        let green: Double
        let blue: Double
    }

    private static func channels(_ hex: UInt32) -> Channels {
        Channels(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        let rgb = channels(hex)
        return 0.2126 * linear(rgb.red) + 0.7152 * linear(rgb.green) + 0.0722 * linear(rgb.blue)
    }

    static func contrastRatio(_ first: UInt32, _ second: UInt32) -> Double {
        let one = relativeLuminance(first)
        let two = relativeLuminance(second)
        return (max(one, two) + 0.05) / (min(one, two) + 0.05)
    }

    /// Shortest distance between two hues, in degrees.
    private static func hueDelta(_ first: UInt32, _ second: UInt32) -> Double {
        let raw = abs(hue(first) - hue(second))
        return min(raw, 360 - raw)
    }

    private static func hue(_ hex: UInt32) -> Double {
        let rgb = channels(hex)
        let highest = max(rgb.red, rgb.green, rgb.blue)
        let lowest = min(rgb.red, rgb.green, rgb.blue)
        let delta = highest - lowest
        guard delta > 0 else { return 0 }
        let degrees: Double
        switch highest {
        case rgb.red:
            degrees = 60 * (((rgb.green - rgb.blue) / delta).truncatingRemainder(dividingBy: 6))
        case rgb.green:
            degrees = 60 * (((rgb.blue - rgb.red) / delta) + 2)
        default:
            degrees = 60 * (((rgb.red - rgb.green) / delta) + 4)
        }
        return degrees < 0 ? degrees + 360 : degrees
    }
}

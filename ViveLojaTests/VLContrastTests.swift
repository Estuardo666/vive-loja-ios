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

    private func backgrounds(_ f: VLFlavor) -> [(String, UInt32)] {
        [
            ("background", f.base),
            ("surface", f.isLight ? f.mantle : f.surface0),
            ("chrome", f.isLight ? f.crust : f.mantle)
        ]
    }

    private func textForegrounds(_ f: VLFlavor) -> [(String, UInt32)] {
        [
            ("text", f.text),
            ("subtext", f.subtext1),
            ("indigo", f.blue),
            ("coral", f.peach),
            ("emerald", f.teal),
            ("navy", f.mauve),
            ("danger", f.red),
            ("warning", f.yellow),
            ("success", f.green)
        ]
    }

    // MARK: Tests

    /// 1.4.3 Contrast (Minimum): 4.5:1 for text under 18pt.
    func testTextTokensMeetAAOnEveryBackground() {
        for sample in drawn {
            for (bgName, bg) in backgrounds(sample.flavor) {
                for (fgName, fg) in textForegrounds(sample.flavor) {
                    let ratio = Self.contrastRatio(fg, bg)
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(sample.name): \(fgName) on \(bgName) is \(String(format: "%.2f", ratio)):1"
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
            for (bgName, bg) in backgrounds(sample.flavor) {
                let ratio = Self.contrastRatio(muted, bg)
                XCTAssertGreaterThanOrEqual(
                    ratio, 3.0,
                    "\(sample.name): muted on \(bgName) is \(String(format: "%.2f", ratio)):1"
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
        let pairs: [(String, VLFlavor, VLFlavor)] = [
            ("latte", .latte, .latteUI),
            ("frappe", .frappe, .frappeUI)
        ]
        let accents: [KeyPath<VLFlavor, UInt32>] = [\.blue, \.peach, \.teal, \.mauve, \.red, \.green]
        for (name, published, corrected) in pairs {
            for accent in accents {
                let delta = Self.hueDelta(published[keyPath: accent], corrected[keyPath: accent])
                XCTAssertLessThanOrEqual(delta, 8.0, "\(name): accent hue moved \(delta)°")
            }
            // The surfaces and the text ramp are never touched.
            XCTAssertEqual(published.base, corrected.base, "\(name): base changed")
            XCTAssertEqual(published.mantle, corrected.mantle, "\(name): mantle changed")
            XCTAssertEqual(published.crust, corrected.crust, "\(name): crust changed")
            XCTAssertEqual(published.text, corrected.text, "\(name): text changed")
            XCTAssertEqual(published.subtext1, corrected.subtext1, "\(name): subtext1 changed")
        }
    }

    // MARK: Colour maths

    private static func channels(_ hex: UInt32) -> (Double, Double, Double) {
        (
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8) & 0xFF) / 255,
            Double(hex & 0xFF) / 255
        )
    }

    private static func relativeLuminance(_ hex: UInt32) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let (r, g, b) = channels(hex)
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func contrastRatio(_ a: UInt32, _ b: UInt32) -> Double {
        let la = relativeLuminance(a)
        let lb = relativeLuminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Shortest distance between two hues, in degrees.
    private static func hueDelta(_ a: UInt32, _ b: UInt32) -> Double {
        let ha = hue(a)
        let hb = hue(b)
        let raw = abs(ha - hb)
        return min(raw, 360 - raw)
    }

    private static func hue(_ hex: UInt32) -> Double {
        let (r, g, b) = channels(hex)
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        guard delta > 0 else { return 0 }
        let h: Double
        switch maxC {
        case r: h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
        case g: h = 60 * (((b - r) / delta) + 2)
        default: h = 60 * (((r - g) / delta) + 4)
        }
        return h < 0 ? h + 360 : h
    }
}

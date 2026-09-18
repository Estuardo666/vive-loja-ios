import UIKit
import XCTest
@testable import ViveLoja

/// Covers the pieces the launch path depends on: the splash gate, the on-disk
/// snapshots that let a warm launch paint before the network answers, and the
/// invalidation that keeps the cached theme colours honest.
final class LaunchPerformanceTests: XCTestCase {
    @MainActor
    func testLaunchGateDismissesEarlyWhenContentArrives() {
        let gate = LaunchGate(delay: .seconds(30))

        gate.dismissNow()

        XCTAssertFalse(gate.isPresented)
    }

    func testSnapshotStoreRoundTripsAPayload() async {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "snapshot-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = SnapshotStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = TodayPayload(
            date: "2026-09-14",
            timeZone: "America/Guayaquil",
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            events: [], openVenues: [], routes: [], collections: []
        )
        await store.write(payload, for: SnapshotStore.Key.today)

        let restored: TodayPayload? = await store.read(SnapshotStore.Key.today)
        XCTAssertEqual(restored?.date, "2026-09-14")
        // Dates survive the round trip, which is what the shared decoder's
        // fractional-seconds handling is there for.
        XCTAssertEqual(restored?.generatedAt.timeIntervalSince1970, 1_700_000_000)
    }

    func testSnapshotStoreReturnsNilForAMissingKey() async {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "snapshot-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = SnapshotStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let restored: TodayPayload? = await store.read(SnapshotStore.Key.today)
        XCTAssertNil(restored)
    }

    func testSnapshotStoreIgnoresKeysOutsidePublicAllowlist() async {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "snapshot-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let store = SnapshotStore(directory: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        await store.write("private", for: "me-profile")
        let restored: String? = await store.read("me-profile")

        XCTAssertNil(restored)
        XCTAssertFalse(FileManager.default.fileExists(at: directory.appending(path: "me-profile.json")))
    }

    /// `VLTheme` caches its dynamic colours, and UIKit memoises a dynamic
    /// colour per trait collection — so without invalidation a palette change
    /// would keep drawing the previous flavour.
    @MainActor
    func testThemeColoursFollowAPaletteChange() {
        let defaults = UserDefaults.standard
        let originalPalette = defaults.string(forKey: VLPalette.storageKey)
        let originalVariation = defaults.string(forKey: VLVariation.storageKey)
        defer {
            defaults.set(originalPalette, forKey: VLPalette.storageKey)
            defaults.set(originalVariation, forKey: VLVariation.storageKey)
            VLTheme.invalidateColorCache()
        }
        let light = UITraitCollection(userInterfaceStyle: .light)

        defaults.set(VLPalette.brand.rawValue, forKey: VLPalette.storageKey)
        defaults.set(VLVariation.viveLoja.rawValue, forKey: VLVariation.storageKey)
        VLTheme.invalidateColorCache()
        let brandBlue = VLTheme.uiColor(\.blue).resolvedColor(with: light)

        defaults.set(VLPalette.catppuccin.rawValue, forKey: VLPalette.storageKey)
        defaults.set(VLVariation.mocha.rawValue, forKey: VLVariation.storageKey)
        VLTheme.invalidateColorCache()
        let catppuccinBlue = VLTheme.uiColor(\.blue).resolvedColor(with: light)

        XCTAssertNotEqual(brandBlue, catppuccinBlue)
    }
}

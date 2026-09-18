# Snapshot baseline

These PNGs are reviewed iPhone 17 Pro / iOS 26.2 Simulator output from GitHub
Actions run [34894203211](https://github.com/Estuardo666/vive-loja-ios/actions/runs/34894203211),
on branch `perf/ios-launch`. They cover every screenshot attachment emitted by
the UI test suite (clear, dark, Dynamic Type, reduced motion/transparency, map,
creation and expired-session recovery).

The previous baseline was captured before the home screen gained its search
bar and before the two accessibility-size captures rendered at an accessibility
size at all — `UICTContentSizeCategoryAccessibility3` and `…Accessibility5` are
not UIKit category names, so those runs were silently rendering at the default
size and `venue-detail-accessibility5` was pixel-identical to
`venue-detail-fixture`. Both are now captured at `AccessibilityXL` and
`AccessibilityXXXL`.

CI maps the human-readable attachment names from `manifest.json` to these files
and compares the app surface. The 180 top rows and 120 bottom rows are ignored
because they contain Simulator-owned status-bar/home-indicator chrome; the app
surface must remain within a 1% mean absolute pixel difference and 2% changed
pixels (8-bit channel threshold 32). Update this baseline only after reviewing
the resulting screenshots on the same device/runtime.

The `explore-map-filter-applied` capture has a small, snapshot-specific tolerance
because MapKit may settle on a different tile/camera raster between simulator
launches; the surrounding controls and card remain part of the comparison.

Anything that moves on its own has to be pinned for these to mean anything:
fixture dates are fixed, and the rotating search placeholder is frozen on its
first word under `-uiTesting` (it advances every 2.4 seconds, so the Explore
captures used to record whichever word happened to be up).

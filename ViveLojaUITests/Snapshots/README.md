# Snapshot baseline

These PNGs are the reviewed iPhone 17 Pro / iOS 26.2 Simulator output from
GitHub Actions run [33562298241](https://github.com/Estuardo666/vive-loja-ios/actions/runs/33562298241),
on commit `9f39b51`. They cover every screenshot attachment emitted by the UI
test suite (clear, dark, Dynamic Type, reduced motion/transparency, map,
creation and expired-session recovery).

CI maps the human-readable attachment names from `manifest.json` to these files
and compares the app surface. The 180 top rows and 120 bottom rows are ignored
because they contain Simulator-owned status-bar/home-indicator chrome; the app
surface must remain within a 1% mean absolute pixel difference and 2% changed
pixels (8-bit channel threshold 32). Update this baseline only after reviewing
the resulting screenshots on the same device/runtime.

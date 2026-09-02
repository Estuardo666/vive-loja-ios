import SwiftUI

/// Approximates a variable blur by stacking material layers, each masked so it
/// stops higher than the one below. UIKit only exposes a single blur radius per
/// view, so a true progressive blur needs either several layers like this or a
/// Metal filter; the layered version is cheap and reads the same at header size.
struct VLProgressiveBlur: View {
    var layers: Int = 4

    var body: some View {
        ZStack {
            ForEach(0..<layers, id: \.self) { index in
                let end = Double(index + 1) / Double(layers)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: max(end - 0.28, 0)),
                                .init(color: .clear, location: end),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Floating header treatment: content sits over a blur that fades out, so
    /// the map underneath reads as full screen.
    func vlProgressiveHeaderBackground() -> some View {
        background {
            ZStack {
                VLProgressiveBlur()
                LinearGradient(
                    stops: [
                        .init(color: VLTheme.background.opacity(0.92), location: 0),
                        .init(color: VLTheme.background.opacity(0.55), location: 0.55),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

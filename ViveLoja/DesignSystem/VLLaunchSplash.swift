import SwiftUI

struct VLBrandLogo: View {
    var side: CGFloat = 172

    var body: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: side * 0.22, style: .continuous))
            .accessibilityLabel("Vive Loja")
    }
}

/// Covers the handoff from `LaunchScreen.storyboard` to the first SwiftUI
/// frame. It draws the same navy ground and the same logo in the same place, so
/// the swap is invisible; it is not a loading screen and never waits on work.
struct VLLaunchSplash: View {
    /// The grain used to be 8_000 separate `Path` allocations and 8_000 fill
    /// calls into the context, rebuilt on every redraw, on the main thread,
    /// during launch. The positions are fixed, so they are generated once per
    /// process and drawn as a single path in one fill.
    private static let grainPositions: [CGPoint] = {
        var positions: [CGPoint] = []
        positions.reserveCapacity(2_500)
        var seed: UInt64 = 42
        for _ in 0..<2_500 {
            seed = seed &* 6364136223846793005 &+ 1
            let positionX = CGFloat(seed % 10_000) / 10_000
            seed = seed &* 6364136223846793005 &+ 1
            let positionY = CGFloat(seed % 10_000) / 10_000
            positions.append(CGPoint(x: positionX, y: positionY))
        }
        return positions
    }()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.12, blue: 0.24),
                         Color(red: 0.02, green: 0.36, blue: 0.46),
                         Color(red: 0.10, green: 0.69, blue: 0.67)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(colors: [.cyan.opacity(0.32), .clear],
                           center: .init(x: 0.85, y: 0.28),
                           startRadius: 0, endRadius: 420)
            Canvas { context, size in
                var grain = Path()
                for position in Self.grainPositions {
                    grain.addRect(CGRect(x: position.x * size.width,
                                         y: position.y * size.height,
                                         width: 1, height: 1))
                }
                context.fill(grain, with: .color(.white.opacity(0.09)))
            }
            .accessibilityHidden(true)
            VLBrandLogo()
                .shadow(color: .black.opacity(0.16), radius: 32, y: 16)
        }
        .ignoresSafeArea()
        .accessibilityIdentifier("launch-splash")
    }
}

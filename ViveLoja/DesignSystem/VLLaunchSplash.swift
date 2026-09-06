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

/// Local artwork renders immediately, before session or network work finishes.
struct VLLaunchSplash: View {
    @State private var isTakingLonger = false

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
            // Deterministic, static grain: no timer or per-frame random work.
            Canvas { context, size in
                var seed: UInt64 = 42
                for _ in 0..<8_000 {
                    seed = seed &* 6364136223846793005 &+ 1
                    let x = CGFloat(seed % 10_000) / 10_000 * size.width
                    seed = seed &* 6364136223846793005 &+ 1
                    let y = CGFloat(seed % 10_000) / 10_000 * size.height
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1, height: 1)),
                                 with: .color(.white.opacity(0.09)))
                }
            }
            .accessibilityHidden(true)
            VLBrandLogo()
                .shadow(color: .black.opacity(0.16), radius: 32, y: 16)
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            VStack(spacing: 14) {
                ProgressView().tint(.white.opacity(0.85))
                    .accessibilityLabel("Preparando inicio")
                if isTakingLonger {
                    Text("Está tardando un poco más…")
                        .font(.footnote)
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 48)
        }
        .accessibilityIdentifier("launch-splash")
        .task {
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            isTakingLonger = true
        }
    }
}

import SwiftUI

/// "Descubre …" with the last word cycling through what the city has to offer.
///
/// `TextField`'s own prompt cannot animate, so the field is given an empty
/// prompt and this view is drawn behind it, hidden as soon as the user types.
/// The timer is driven by the view's own task, so it stops when the search bar
/// leaves the screen instead of ticking for the life of the app.
struct RotatingSearchPlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ten words covering both halves of the guide — what to do and where to
    /// go — so the field reads as a city search rather than a venue search.
    static let words = [
        "restaurantes", "eventos", "teatros", "cafeterías", "hoteles",
        "bares", "museos", "Loja", "El Valle", "conciertos",
    ]

    private static let interval: Duration = .seconds(2.4)

    @State private var index = 0

    var body: some View {
        HStack(spacing: 5) {
            Text("Descubre")
            Text(Self.words[index])
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .id(reduceMotion ? 0 : index)
                .transition(.opacity)
            Spacer(minLength: 0)
        }
        .font(.body)
        .foregroundStyle(.secondary)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                guard !Task.isCancelled else { return }
                withAnimation(.snappy) { index = (index + 1) % Self.words.count }
            }
        }
    }
}

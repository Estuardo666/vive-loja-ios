import SwiftUI

enum VLTheme {
    static let indigo = Color(red: 0.25, green: 0.25, blue: 0.78)
    static let coral = Color(red: 0.94, green: 0.32, blue: 0.31)
    static let emerald = Color(red: 0.10, green: 0.56, blue: 0.38)

    static func itemColor(_ item: ExploreItem) -> Color {
        switch item {
        case .venue: return emerald
        case .event: return coral
        }
    }
}

struct VLGlassModifier: ViewModifier {
    let tint: Color?
    let radius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(1)
            .glassEffect(.regular.tint(tint), in: shape)
            .clipShape(shape)
    }
}

extension View {
    func vlGlass(tint: Color? = nil, radius: CGFloat = 20) -> some View {
        modifier(VLGlassModifier(tint: tint, radius: radius))
    }
}

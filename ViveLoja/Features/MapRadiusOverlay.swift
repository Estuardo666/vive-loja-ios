import MapKit
import SwiftUI

/// Screen-space projection of the search area, republished as the map moves.
///
/// The radius used to be an MKCircle. MapKit redraws overlays rather than
/// interpolating them, so it jumped on every pan and snapped between radii.
/// Projecting to points and drawing in SwiftUI instead buys real animation,
/// a dashed stroke and any line width we want.
///
/// It is `@Observable` on purpose: only the ring reads these values, so the
/// per-frame updates during a pan do not re-evaluate the whole explore screen.
@MainActor
@Observable
final class MapProjection {
    var center: CGPoint = .zero
    var radiusPoints: CGFloat = 0
    /// False while the projection is unusable, e.g. before the first layout.
    var isValid = false

    func update(center: CGPoint, radiusPoints: CGFloat) {
        self.center = center
        self.radiusPoints = radiusPoints
        isValid = radiusPoints > 0
    }
}

/// Dashed ring marking the search radius, drawn over the map.
struct MapRadiusRing: View {
    let projection: MapProjection
    /// Hidden while a route is on screen; the two compete for attention.
    let isHidden: Bool

    var body: some View {
        if projection.isValid, !isHidden {
            Circle()
                .strokeBorder(
                    VLTheme.indigo.opacity(0.85),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5], dashPhase: 0)
                )
                .background(Circle().fill(VLTheme.indigo.opacity(0.05)))
                .frame(width: projection.radiusPoints * 2, height: projection.radiusPoints * 2)
                .position(projection.center)
                .allowsHitTesting(false)
                // Size changes come from the radius picker and deserve a spring;
                // position changes come from panning and must stay glued to the
                // map, so they are not animated.
                .animation(.spring(response: 0.45, dampingFraction: 0.8), value: projection.radiusPoints)
                .transition(.opacity)
        }
    }
}

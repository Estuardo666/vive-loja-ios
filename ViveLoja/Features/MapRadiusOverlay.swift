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
        // Every write to an @Observable property wakes the ring, and this runs
        // on each frame of a pan, so skip the ones that change nothing.
        if self.center != center { self.center = center }
        if self.radiusPoints != radiusPoints { self.radiusPoints = radiusPoints }
        let valid = radiusPoints > 0
        if isValid != valid { isValid = valid }
    }
}

/// The ring itself, as a `Shape` rather than a sized-and-positioned `Circle`.
///
/// A `Circle` with `.frame(width:height:).position()` re-runs SwiftUI layout on
/// every frame of a pan; a shape that draws straight from the projection only
/// rebuilds one path, which is what keeps the ring glued to the map.
private struct RadiusShape: Shape {
    var center: CGPoint
    var radius: CGFloat

    /// Lets the radius picker interpolate the ring instead of snapping it.
    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(center.x, center.y), radius) }
        set {
            center = CGPoint(x: newValue.first.first, y: newValue.first.second)
            radius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        Path(ellipseIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))
    }
}

/// Dashed ring marking the search radius, drawn over the map.
///
/// It sits on top of a basemap we do not control — streets, satellite imagery,
/// dark mode — so the indigo stroke rides on a translucent white casing, the
/// same trick the route polyline uses. Without it the ring disappears over
/// aerial photography.
struct MapRadiusRing: View {
    let projection: MapProjection
    /// Hidden while a route is on screen; the two compete for attention.
    let isHidden: Bool

    private var shape: RadiusShape {
        RadiusShape(center: projection.center, radius: projection.radiusPoints)
    }

    var body: some View {
        if projection.isValid, !isHidden {
            ZStack {
                shape.fill(VLTheme.indigo.opacity(0.12))
                shape.stroke(Color.white.opacity(0.75), lineWidth: 5.5)
                shape.stroke(
                    VLTheme.indigo,
                    style: StrokeStyle(lineWidth: 2.5, dash: [11, 7], dashPhase: 0)
                )
                centerPin
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.18), radius: 3, y: 1)
            .allowsHitTesting(false)
            // Deliberately no implicit animation. Both the centre and the
            // radius change on every frame of a pan or a zoom, so animating
            // them makes the ring chase the map a few frames behind. The radius
            // picker animates the map region itself, and the ring rides along.
            .transition(.opacity)
        }
    }

    /// Marks the anchor the search actually ran from, which is not always the
    /// middle of the screen once you start panning.
    private var centerPin: some View {
        Circle()
            .fill(VLTheme.indigo)
            .frame(width: 9, height: 9)
            .overlay(Circle().stroke(Color.white.opacity(0.9), lineWidth: 2))
            .position(projection.center)
    }
}

import MapKit
import SwiftUI

/// Native MapKit surface used for the explore map. MKMapView is intentional here:
/// it gives us clustering, delegate selection and overlays that the SwiftUI Map
/// abstraction does not expose consistently across iOS releases.
struct ClusteredMapView: UIViewRepresentable {
    let items: [ExploreItem]
    @Binding var region: MKCoordinateRegion
    @Binding var selectedItemID: String?
    let radiusMeters: CLLocationDistance
    /// Anchor for the search area. It is set explicitly by the caller and only
    /// moves when a search actually runs — deriving it from the live region made
    /// the overlay rebuild on every pan, which is what made it flicker.
    let circleCenter: CLLocationCoordinate2D
    /// Avatar drawn on the blue dot, when the signed-in user has one.
    let userPhotoURL: URL?
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.accessibilityIdentifier = "explore-map"
        mapView.delegate = context.coordinator
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = configuration
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        // Flat, north-up rendering: cheaper to draw and the extra freedom buys
        // nothing on a city map.
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        mapView.setRegion(region, animated: false)
        context.coordinator.syncSpotlight(on: mapView, center: circleCenter, radius: radiusMeters)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        let currentAnnotations = mapView.annotations.compactMap { $0 as? MapItemAnnotation }
        let currentIDs = Set(currentAnnotations.map(\.id))
        let incoming = items.compactMap(MapItemAnnotation.init)
        let incomingIDs = Set(incoming.map(\.id))
        let stale = currentAnnotations.filter { !incomingIDs.contains($0.id) }
        if !stale.isEmpty { mapView.removeAnnotations(stale) }
        let added = incoming.filter { !currentIDs.contains($0.id) }
        if !added.isEmpty { mapView.addAnnotations(added) }

        context.coordinator.syncSpotlight(on: mapView, center: circleCenter, radius: radiusMeters)
        context.coordinator.refreshUserAvatar(on: mapView, url: userPhotoURL)

        if selectedItemID == nil, !mapView.selectedAnnotations.isEmpty {
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: false) }
        }

        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView
        private var spotlightCenter: CLLocationCoordinate2D?
        private var spotlightRadius: CLLocationDistance?
        private var appliedAvatarURL: URL?

        init(parent: ClusteredMapView) { self.parent = parent }

        /// Replaces the scrim only when the area it describes actually moved.
        func syncSpotlight(on mapView: MKMapView, center: CLLocationCoordinate2D, radius: CLLocationDistance) {
            if let spotlightCenter, let spotlightRadius,
               abs(spotlightCenter.latitude - center.latitude) < 0.00001,
               abs(spotlightCenter.longitude - center.longitude) < 0.00001,
               abs(spotlightRadius - radius) < 1 {
                return
            }
            mapView.removeOverlays(mapView.overlays.filter { $0 is MapSpotlightOverlay })
            mapView.addOverlay(MapSpotlightOverlay.make(center: center, radius: radius), level: .aboveLabels)
            spotlightCenter = center
            spotlightRadius = radius
        }

        func refreshUserAvatar(on mapView: MKMapView, url: URL?) {
            guard url != appliedAvatarURL else { return }
            appliedAvatarURL = url
            guard let userView = mapView.view(for: mapView.userLocation) as? UserAvatarAnnotationView else { return }
            userView.configure(with: url)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                guard parent.userPhotoURL != nil else { return nil }
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: UserAvatarAnnotationView.reuseID)
                    as? UserAvatarAnnotationView ?? UserAvatarAnnotationView(annotation: annotation, reuseIdentifier: UserAvatarAnnotationView.reuseID)
                view.configure(with: parent.userPhotoURL)
                return view
            }
            if let cluster = annotation as? MKClusterAnnotation { return clusterView(mapView, for: cluster) }
            guard let item = annotation as? MapItemAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: MapItemAnnotation.reuseID)
                as? ItemPhotoAnnotationView ?? ItemPhotoAnnotationView(annotation: item, reuseIdentifier: MapItemAnnotation.reuseID)
            view.configure(with: item)
            return view
        }

        private func clusterView(_ mapView: MKMapView, for cluster: MKClusterAnnotation) -> MKAnnotationView? {
            let identifier = "explore-cluster"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: cluster, reuseIdentifier: identifier)
            view.annotation = cluster
            view.markerTintColor = UIColor(VLTheme.indigo)
            view.glyphText = "\(cluster.memberAnnotations.count)"
            view.displayPriority = .defaultHigh
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                mapView.deselectAnnotation(cluster, animated: false)
                let region = MKCoordinateRegion(
                    center: cluster.coordinate,
                    span: MKCoordinateSpan(
                        latitudeDelta: max(mapView.region.span.latitudeDelta / 3, 0.002),
                        longitudeDelta: max(mapView.region.span.longitudeDelta / 3, 0.002)
                    )
                )
                mapView.setRegion(region, animated: true)
                return
            }
            guard let item = view.annotation as? MapItemAnnotation else { return }
            parent.selectedItemID = item.id
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Writing the region back re-enters updateUIView, so only do it when
            // the map really settled somewhere else.
            guard !mapView.region.isApproximatelyEqual(to: parent.region) else { return }
            parent.onRegionChange(mapView.region)
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let spotlight = overlay as? MapSpotlightOverlay else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolygonRenderer(polygon: spotlight)
            // Even-odd fill: the world is dimmed, the radius stays clear, so the
            // streets inside the search area remain readable.
            renderer.fillColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor.black.withAlphaComponent(0.58)
                    : UIColor.black.withAlphaComponent(0.20)
            }
            renderer.strokeColor = UIColor(VLTheme.indigo)
            renderer.lineWidth = 2.5
            return renderer
        }
    }
}

/// World polygon with the search radius punched out, so everything *outside* the
/// radius is dimmed. Drawing a filled circle on top of a dark scrim instead made
/// the inside look lighter than the surrounding map and hid the street names.
final class MapSpotlightOverlay: MKPolygon {
    private static let circleSegments = 90

    static func make(center: CLLocationCoordinate2D, radius: CLLocationDistance) -> MapSpotlightOverlay {
        let rect = MKMapRect.world
        let outer = [
            MKMapPoint(x: rect.minX, y: rect.minY),
            MKMapPoint(x: rect.maxX, y: rect.minY),
            MKMapPoint(x: rect.maxX, y: rect.maxY),
            MKMapPoint(x: rect.minX, y: rect.maxY),
        ]
        let hole = circle(center: center, radius: radius)
        return MapSpotlightOverlay(points: outer, count: outer.count, interiorPolygons: [hole])
    }

    private static func circle(center: CLLocationCoordinate2D, radius: CLLocationDistance) -> MKPolygon {
        let earthRadius = 6_371_000.0
        let latitudeDelta = radius / earthRadius * 180 / .pi
        let longitudeDelta = latitudeDelta / max(cos(center.latitude * .pi / 180), 0.000001)
        let coordinates = (0..<circleSegments).map { step -> CLLocationCoordinate2D in
            let angle = Double(step) / Double(circleSegments) * 2 * .pi
            return CLLocationCoordinate2D(
                latitude: center.latitude + latitudeDelta * sin(angle),
                longitude: center.longitude + longitudeDelta * cos(angle)
            )
        }
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
}

final class MapItemAnnotation: NSObject, MKAnnotation {
    static let reuseID = "explore-item"

    let item: ExploreItem
    let coordinate: CLLocationCoordinate2D
    let id: String
    let title: String?
    let isVenue: Bool
    let imageURL: URL?

    init?(item: ExploreItem) {
        guard let coordinate = item.coordinate else { return nil }
        self.item = item
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
        self.id = item.id
        self.title = item.title
        self.isVenue = if case .venue = item { true } else { false }
        self.imageURL = switch item {
        case .venue(let value): value.image
        case .event(let value): value.image
        }
        super.init()
    }
}

private extension MKCoordinateRegion {
    func isApproximatelyEqual(to other: MKCoordinateRegion) -> Bool {
        abs(center.latitude - other.center.latitude) < 0.0001
            && abs(center.longitude - other.center.longitude) < 0.0001
            && abs(span.latitudeDelta - other.span.latitudeDelta) < 0.0001
            && abs(span.longitudeDelta - other.span.longitudeDelta) < 0.0001
    }
}

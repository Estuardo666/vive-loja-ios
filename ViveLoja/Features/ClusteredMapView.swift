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
    /// When set (near-me is on) the radius circle stays anchored here instead of
    /// following the map centre, so panning no longer drags the search area.
    let circleCenter: CLLocationCoordinate2D?
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
        // Sits above the basemap labels but below annotations, so the map goes dark
        // enough for the radius circle to read while our pins stay bright.
        mapView.addOverlay(MapDimOverlay.world(), level: .aboveLabels)
        mapView.setRegion(region, animated: false)
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

        let center = circleCenter ?? region.center
        let currentCircle = mapView.overlays.compactMap { $0 as? MKCircle }.first
        if circleNeedsUpdate(currentCircle, center: center) {
            mapView.removeOverlays(mapView.overlays.compactMap { $0 as? MKCircle })
            mapView.addOverlay(MKCircle(center: center, radius: radiusMeters), level: .aboveLabels)
        }

        if selectedItemID == nil, !mapView.selectedAnnotations.isEmpty {
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: false) }
        }

        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
    }

    private func circleNeedsUpdate(_ circle: MKCircle?, center: CLLocationCoordinate2D) -> Bool {
        guard let circle else { return true }
        let latitudeDelta: CLLocationDegrees = abs(circle.coordinate.latitude - center.latitude)
        let longitudeDelta: CLLocationDegrees = abs(circle.coordinate.longitude - center.longitude)
        let radiusDelta: CLLocationDistance = abs(circle.radius - radiusMeters)
        if latitudeDelta > 0.00001 { return true }
        if longitudeDelta > 0.00001 { return true }
        return radiusDelta > 1
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView

        init(parent: ClusteredMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
            parent.onRegionChange(mapView.region)
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let dim = overlay as? MapDimOverlay {
                let renderer = MKPolygonRenderer(polygon: dim)
                // Dark theme needs a heavy scrim for the radius circle to read.
                // Light theme only needs the basemap calmed down.
                renderer.fillColor = UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor.black.withAlphaComponent(0.55)
                        : UIColor.white.withAlphaComponent(0.30)
                }
                renderer.strokeColor = .clear
                renderer.lineWidth = 0
                return renderer
            }
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor(VLTheme.indigo).withAlphaComponent(0.22)
            renderer.strokeColor = UIColor(VLTheme.indigo).withAlphaComponent(0.95)
            renderer.lineWidth = 3
            return renderer
        }
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

/// World-covering polygon used purely to darken the basemap.
final class MapDimOverlay: MKPolygon {
    static func world() -> MapDimOverlay {
        let rect = MKMapRect.world
        let points = [
            MKMapPoint(x: rect.minX, y: rect.minY),
            MKMapPoint(x: rect.maxX, y: rect.minY),
            MKMapPoint(x: rect.maxX, y: rect.maxY),
            MKMapPoint(x: rect.minX, y: rect.maxY),
        ]
        return MapDimOverlay(points: points, count: points.count)
    }
}

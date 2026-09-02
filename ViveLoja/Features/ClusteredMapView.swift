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
        configuration.pointOfInterestFilter = .includingAll
        mapView.preferredConfiguration = configuration
        mapView.overrideUserInterfaceStyle = .dark
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        let oldAnnotations = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(oldAnnotations)
        mapView.addAnnotations(items.compactMap(MapItemAnnotation.init))

        let center = circleCenter ?? region.center
        let existing = mapView.overlays.compactMap { $0 as? MKCircle }.first
        let needsCircle = existing.map {
            abs($0.coordinate.latitude - center.latitude) > 0.00001
                || abs($0.coordinate.longitude - center.longitude) > 0.00001
                || abs($0.radius - radiusMeters) > 1
        } ?? true
        if needsCircle {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(MKCircle(center: center, radius: radiusMeters))
        }

        if !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView

        init(parent: ClusteredMapView) { self.parent = parent }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let item = annotation as? MapItemAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: MapItemAnnotation.reuseID)
                as? MKMarkerAnnotationView ?? MKMarkerAnnotationView(annotation: item, reuseIdentifier: MapItemAnnotation.reuseID)
            view.annotation = item
            view.markerTintColor = UIColor(VLTheme.itemColor(item.item))
            view.glyphImage = UIImage(systemName: item.isVenue ? "mappin" : "calendar")
            view.clusteringIdentifier = "explore-items"
            view.displayPriority = .defaultHigh
            view.titleVisibility = .adaptive
            return view
        }

        func mapView(_ mapView: MKMapView, viewFor cluster: MKClusterAnnotation) -> MKAnnotationView? {
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
            guard let item = view.annotation as? MapItemAnnotation else { return }
            parent.selectedItemID = item.id
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = UIColor(VLTheme.indigo).withAlphaComponent(0.22)
            renderer.strokeColor = UIColor(VLTheme.indigo).withAlphaComponent(0.95)
            renderer.lineWidth = 3
            return renderer
        }
    }
}

private final class MapItemAnnotation: NSObject, MKAnnotation {
    static let reuseID = "explore-item"

    let item: ExploreItem
    let coordinate: CLLocationCoordinate2D
    let id: String
    let title: String?
    let isVenue: Bool

    init?(item: ExploreItem) {
        guard let coordinate = item.coordinate else { return nil }
        self.item = item
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.lat, longitude: coordinate.lng)
        self.id = item.id
        self.title = item.title
        self.isVenue = if case .venue = item { true } else { false }
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

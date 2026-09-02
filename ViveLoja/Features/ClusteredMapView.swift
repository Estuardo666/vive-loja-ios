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

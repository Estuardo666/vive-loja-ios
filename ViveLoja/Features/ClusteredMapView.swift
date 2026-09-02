import MapKit
import SwiftUI

/// The basemap looks MapKit offers. There is no JSON styling as in Google Maps;
/// the platform exposes these configurations plus the light/dark appearance,
/// which it applies to the basemap itself. That is why the explore map no longer
/// paints a scrim of its own: a dark tint over the tiles buried the street names.
enum MapStyleOption: String, CaseIterable, Identifiable, Sendable {
    case standard
    case muted
    case satellite
    case hybrid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Estándar"
        case .muted: return "Silenciado"
        case .satellite: return "Satélite"
        case .hybrid: return "Híbrido"
        }
    }

    var symbol: String {
        switch self {
        case .standard: return "map"
        case .muted: return "map.fill"
        case .satellite: return "globe.americas"
        case .hybrid: return "globe.americas.fill"
        }
    }

    var configuration: MKMapConfiguration {
        switch self {
        case .standard:
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .default)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .muted:
            let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        case .satellite:
            return MKImageryMapConfiguration(elevationStyle: .flat)
        case .hybrid:
            let configuration = MKHybridMapConfiguration(elevationStyle: .flat)
            configuration.pointOfInterestFilter = .excludingAll
            return configuration
        }
    }
}

/// Native MapKit surface used for the explore map. MKMapView is intentional here:
/// it gives us clustering, delegate selection and overlays that the SwiftUI Map
/// abstraction does not expose consistently across iOS releases.
struct ClusteredMapView: UIViewRepresentable {
    let items: [ExploreItem]
    @Binding var region: MKCoordinateRegion
    @Binding var selectedItemID: String?
    let radiusMeters: CLLocationDistance
    /// Anchor for the search area. Set explicitly by the caller and only moved
    /// when a search runs — deriving it from the live region made the overlay
    /// rebuild on every pan, which is what made it flicker.
    let circleCenter: CLLocationCoordinate2D
    let userPhotoURL: URL?
    /// Screen-space projection of the search area, drawn by SwiftUI on top.
    let projection: MapProjection
    let mapStyle: MapStyleOption
    /// Active route, drawn under the pins. Hides the radius ring while set.
    let route: MKRoute?
    /// While guiding, MapKit owns the camera and follows the user's heading.
    let isGuiding: Bool
    let onRegionChange: (MKCoordinateRegion) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.accessibilityIdentifier = "explore-map"
        mapView.delegate = context.coordinator
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.showsUserLocation = true
        mapView.isPitchEnabled = false
        mapView.setRegion(region, animated: false)
        context.coordinator.applyStyle(mapStyle, to: mapView)
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

        context.coordinator.applyStyle(mapStyle, to: mapView)
        context.coordinator.syncRoute(on: mapView, route: route)
        Task { @MainActor in context.coordinator.publishProjection(mapView) }
        context.coordinator.applyGuidance(isGuiding, to: mapView)
        context.coordinator.refreshUserAvatar(on: mapView, url: userPhotoURL)

        if selectedItemID == nil, !mapView.selectedAnnotations.isEmpty {
            mapView.selectedAnnotations.forEach { mapView.deselectAnnotation($0, animated: false) }
        }

        // While guiding MapKit drives the camera; forcing a region would fight it.
        if !isGuiding, !mapView.region.isApproximatelyEqual(to: region) {
            mapView.setRegion(region, animated: true)
        }
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ClusteredMapView
        private var appliedAvatarURL: URL?
        private var appliedStyle: MapStyleOption?
        private var appliedRoute: MKRoute?
        private var appliedGuidance = false

        init(parent: ClusteredMapView) { self.parent = parent }

        func applyStyle(_ style: MapStyleOption, to mapView: MKMapView) {
            guard style != appliedStyle else { return }
            appliedStyle = style
            mapView.preferredConfiguration = style.configuration
        }

        /// Recomputes where the search area lands on screen. Called on every
        /// frame of a gesture so the SwiftUI ring stays glued to the map.
        func publishProjection(_ mapView: MKMapView) {
            let region = MKCoordinateRegion(
                center: parent.circleCenter,
                latitudinalMeters: parent.radiusMeters * 2,
                longitudinalMeters: parent.radiusMeters * 2
            )
            let rect = mapView.convert(region, toRectTo: mapView)
            guard rect.width.isFinite, rect.height.isFinite else { return }
            parent.projection.update(
                center: CGPoint(x: rect.midX, y: rect.midY),
                radiusPoints: rect.width / 2
            )
        }

        func syncRoute(on mapView: MKMapView, route: MKRoute?) {
            guard route !== appliedRoute else { return }
            appliedRoute = route
            mapView.removeOverlays(mapView.overlays.filter { $0 is RouteCasingPolyline || $0 is RoutePolyline })
            guard let route else { return }
            let points = route.polyline.points()
            let casing = RouteCasingPolyline(points: points, count: route.polyline.pointCount)
            let line = RoutePolyline(points: points, count: route.polyline.pointCount)
            mapView.addOverlay(casing, level: .aboveRoads)
            mapView.addOverlay(line, level: .aboveRoads)
        }

        func applyGuidance(_ isGuiding: Bool, to mapView: MKMapView) {
            guard isGuiding != appliedGuidance else { return }
            appliedGuidance = isGuiding
            // Heading-follow needs rotation, which we keep off for browsing.
            mapView.isRotateEnabled = isGuiding
            mapView.setUserTrackingMode(isGuiding ? .followWithHeading : .none, animated: true)
            if !isGuiding {
                let camera = mapView.camera
                camera.heading = 0
                mapView.setCamera(camera, animated: true)
            }
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

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            publishProjection(mapView)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard !parent.isGuiding else { return }
            // Writing the region back re-enters updateUIView, so only do it when
            // the map really settled somewhere else.
            guard !mapView.region.isApproximatelyEqual(to: parent.region) else { return }
            parent.onRegionChange(mapView.region)
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let casing = overlay as? RouteCasingPolyline {
                let renderer = MKPolylineRenderer(polyline: casing)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.9)
                renderer.lineWidth = 11
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            if let line = overlay as? RoutePolyline {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor(VLTheme.indigo)
                renderer.lineWidth = 7
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

/// Distinct subclasses so the renderer can tell the two route layers apart.
final class RoutePolyline: MKPolyline {}
final class RouteCasingPolyline: MKPolyline {}

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

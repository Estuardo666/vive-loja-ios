import CoreLocation
import MapKit
import Observation

/// Turn-by-turn guidance built on MKDirections.
///
/// Deliberately silent: there is no speech synthesis and no background location
/// entitlement, so guidance runs only while the app is in the foreground. For
/// hands-free navigation the detail screen still hands off to Apple Maps.
@MainActor
@Observable
final class RouteService {
    enum Mode: String, CaseIterable, Identifiable, Sendable {
        case automobile
        case walking

        var id: String { rawValue }
        var label: String { self == .automobile ? "En auto" : "A pie" }
        var symbol: String { self == .automobile ? "car.fill" : "figure.walk" }
        var transportType: MKDirectionsTransportType { self == .automobile ? .automobile : .walking }
    }

    struct Destination: Equatable, Sendable {
        let name: String
        let latitude: Double
        let longitude: Double

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }

    /// Distance from the route beyond which we assume the user left it.
    private static let offRouteThreshold: CLLocationDistance = 60
    /// Consecutive off-route fixes before recalculating, so one bad GPS sample
    /// does not trigger a reroute.
    private static let offRouteTolerance = 3
    /// How close to a manoeuvre counts as having taken it.
    private static let manoeuvreReachedThreshold: CLLocationDistance = 25
    private static let arrivalThreshold: CLLocationDistance = 40

    private(set) var route: MKRoute?
    private(set) var destination: Destination?
    private(set) var currentStepIndex = 0
    private(set) var isCalculating = false
    private(set) var isGuiding = false
    private(set) var hasArrived = false
    private(set) var errorMessage: String?
    private(set) var distanceToNextManeuver: CLLocationDistance = 0
    private(set) var remainingDistance: CLLocationDistance = 0
    private(set) var remainingTime: TimeInterval = 0
    private(set) var isRerouting = false
    private(set) var mode: Mode = .automobile

    private var offRouteHits = 0
    private var pendingDirections: MKDirections?

    /// Steps worth showing. MapKit's first step is a filler ("Proceed to...")
    /// with an empty instruction on most routes.
    var steps: [MKRoute.Step] {
        (route?.steps ?? []).filter { !$0.instructions.isEmpty }
    }

    var currentStep: MKRoute.Step? {
        let visible = steps
        guard visible.indices.contains(currentStepIndex) else { return visible.last }
        return visible[currentStepIndex]
    }

    var nextStep: MKRoute.Step? {
        let visible = steps
        let index = currentStepIndex + 1
        return visible.indices.contains(index) ? visible[index] : nil
    }

    func start(to destination: Destination, from origin: CLLocationCoordinate2D, mode: Mode) async {
        self.destination = destination
        self.mode = mode
        hasArrived = false
        currentStepIndex = 0
        offRouteHits = 0
        await calculate(from: origin)
        if route != nil { isGuiding = true }
    }

    func changeMode(_ mode: Mode, from origin: CLLocationCoordinate2D) async {
        guard mode != self.mode else { return }
        self.mode = mode
        currentStepIndex = 0
        offRouteHits = 0
        await calculate(from: origin)
    }

    func stop() {
        pendingDirections?.cancel()
        pendingDirections = nil
        route = nil
        destination = nil
        isGuiding = false
        isCalculating = false
        isRerouting = false
        hasArrived = false
        currentStepIndex = 0
        offRouteHits = 0
        errorMessage = nil
        distanceToNextManeuver = 0
        remainingDistance = 0
        remainingTime = 0
    }

    /// Feeds a new fix into the guidance state machine.
    func update(with location: CLLocation) async {
        guard isGuiding, let route, let destination else { return }

        let userPoint = MKMapPoint(location.coordinate)
        let destinationDistance = location.distance(from: CLLocation(latitude: destination.latitude, longitude: destination.longitude))
        if destinationDistance <= Self.arrivalThreshold {
            hasArrived = true
            isGuiding = false
            VLFeedback.success()
            return
        }

        advanceStepIfReached(from: userPoint)
        recomputeRemaining(from: location, route: route)

        let deviation = Self.distance(from: userPoint, to: route.polyline)
        if deviation > Self.offRouteThreshold {
            offRouteHits += 1
            if offRouteHits >= Self.offRouteTolerance, !isCalculating {
                offRouteHits = 0
                isRerouting = true
                currentStepIndex = 0
                await calculate(from: location.coordinate)
                isRerouting = false
            }
        } else {
            offRouteHits = 0
        }
    }

    private func advanceStepIfReached(from userPoint: MKMapPoint) {
        let visible = steps
        guard visible.indices.contains(currentStepIndex) else { return }
        let step = visible[currentStepIndex]
        guard let end = Self.lastCoordinate(of: step.polyline) else { return }
        let distance = userPoint.distance(to: MKMapPoint(end))
        distanceToNextManeuver = distance
        if distance <= Self.manoeuvreReachedThreshold, currentStepIndex < visible.count - 1 {
            currentStepIndex += 1
            VLFeedback.selection()
        }
    }

    private func recomputeRemaining(from location: CLLocation, route: MKRoute) {
        let visible = steps
        let remainingSteps = visible.dropFirst(currentStepIndex)
        let stepsDistance = remainingSteps.reduce(0) { $0 + $1.distance }
        remainingDistance = max(stepsDistance, 0)
        // MKRoute only gives a total, so scale it by how much distance is left.
        let ratio = route.distance > 0 ? remainingDistance / route.distance : 0
        remainingTime = route.expectedTravelTime * min(max(ratio, 0), 1)
    }

    private func calculate(from origin: CLLocationCoordinate2D) async {
        guard let destination else { return }
        pendingDirections?.cancel()
        isCalculating = true
        errorMessage = nil
        defer { isCalculating = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = mode.transportType
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        pendingDirections = directions
        do {
            let response = try await directions.calculate()
            guard let best = response.routes.first else {
                errorMessage = "No encontramos una ruta hasta este lugar."
                return
            }
            route = best
            remainingDistance = best.distance
            remainingTime = best.expectedTravelTime
        } catch is CancellationError {
            return
        } catch {
            // A cancelled MKDirections request surfaces as a plain NSError.
            if (error as NSError).code == MKError.loadingThrottled.rawValue {
                errorMessage = "Demasiadas rutas seguidas. Espera un momento."
            } else {
                errorMessage = "No se pudo calcular la ruta. Revisa tu conexión."
            }
        }
    }

    // MARK: - Geometry

    private static func lastCoordinate(of polyline: MKPolyline) -> CLLocationCoordinate2D? {
        guard polyline.pointCount > 0 else { return nil }
        return polyline.points()[polyline.pointCount - 1].coordinate
    }

    /// Shortest distance from a point to a polyline, in metres.
    static func distance(from point: MKMapPoint, to polyline: MKPolyline) -> CLLocationDistance {
        let points = polyline.points()
        guard polyline.pointCount > 1 else {
            return polyline.pointCount == 1 ? point.distance(to: points[0]) : .greatestFiniteMagnitude
        }
        var best = CLLocationDistance.greatestFiniteMagnitude
        for index in 0..<(polyline.pointCount - 1) {
            let distance = point.distance(toSegmentFrom: points[index], to: points[index + 1])
            if distance < best { best = distance }
        }
        return best
    }
}

private extension MKMapPoint {
    /// Perpendicular distance to a segment, falling back to the endpoints when
    /// the projection lands outside it.
    func distance(toSegmentFrom start: MKMapPoint, to end: MKMapPoint) -> CLLocationDistance {
        let dx = end.x - start.x
        let dy = end.y - start.y
        if dx == 0, dy == 0 { return distance(to: start) }
        let t = ((x - start.x) * dx + (y - start.y) * dy) / (dx * dx + dy * dy)
        if t <= 0 { return distance(to: start) }
        if t >= 1 { return distance(to: end) }
        let projection = MKMapPoint(x: start.x + t * dx, y: start.y + t * dy)
        return distance(to: projection)
    }
}

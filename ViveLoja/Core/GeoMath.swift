import CoreLocation

enum GeoMath {
    static let earthRadiusMeters = 6_371_000.0

    static func distanceMeters(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) -> CLLocationDistance {
        let latitudeDelta = (destination.latitude - origin.latitude) * .pi / 180
        let longitudeDelta = (destination.longitude - origin.longitude) * .pi / 180
        let latitude1 = origin.latitude * .pi / 180
        let latitude2 = destination.latitude * .pi / 180
        let value = sin(latitudeDelta / 2) * sin(latitudeDelta / 2)
            + cos(latitude1) * cos(latitude2) * sin(longitudeDelta / 2) * sin(longitudeDelta / 2)
        return earthRadiusMeters * 2 * atan2(sqrt(value), sqrt(max(0, 1 - value)))
    }

    static func contains(_ coordinate: CLLocationCoordinate2D, in radius: CLLocationDistance, around center: CLLocationCoordinate2D) -> Bool {
        distanceMeters(from: center, to: coordinate) <= radius
    }
}

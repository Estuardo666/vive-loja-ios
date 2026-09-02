import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var coordinate: (lat: Double, lng: Double)?
    var isRequesting = false
    var errorMessage: String?
    /// Last known position with its accuracy and course, needed while guiding a
    /// route. `coordinate` stays for the callers that only want a fix.
    private(set) var location: CLLocation?
    private(set) var isTracking = false
    /// True once the user has actively refused; callers use it to explain why a
    /// location-dependent feature is unavailable instead of failing silently.
    private(set) var isDenied = false

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestCurrentLocation() {
        errorMessage = nil
        isRequesting = true
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isRequesting = false
            isDenied = true
            errorMessage = "Activa la ubicación para usar esta función."
        @unknown default:
            isRequesting = false
            errorMessage = "No se pudo obtener tu ubicación."
        }
    }

    /// Continuous updates for turn-by-turn guidance. Foreground only: the app
    /// has no background location entitlement and guidance stops with the app.
    func startTracking() {
        guard !isTracking else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isTracking = true
            manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
            manager.distanceFilter = 5
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            isDenied = true
            errorMessage = "Activa la ubicación para usar esta función."
        @unknown default:
            break
        }
    }

    func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        manager.stopUpdatingLocation()
        // Guidance accuracy is expensive; drop back once we no longer need it.
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = kCLDistanceFilterNone
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.isDenied = false
                if self.isTracking {
                    self.manager.startUpdatingLocation()
                } else {
                    self.manager.requestLocation()
                }
            } else if status == .denied || status == .restricted {
                self.isRequesting = false
                self.isDenied = true
                self.errorMessage = "Activa la ubicación para usar esta función."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor [weak self] in
            self?.location = last
            self?.coordinate = (last.coordinate.latitude, last.coordinate.longitude)
            self?.isRequesting = false
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.isRequesting = false
            self?.errorMessage = "No se pudo obtener tu ubicación. Intenta de nuevo."
        }
    }
}

import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    var coordinate: (lat: Double, lng: Double)?
    var isRequesting = false
    var errorMessage: String?
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
            errorMessage = "Activa la ubicación para registrar tu visita."
        @unknown default:
            isRequesting = false
            errorMessage = "No se pudo obtener tu ubicación."
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.manager.requestLocation()
            } else if status == .denied || status == .restricted {
                self.isRequesting = false
                self.errorMessage = "Activa la ubicación para registrar tu visita."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude
        let lng = last.coordinate.longitude
        Task { @MainActor [weak self] in
            self?.coordinate = (lat, lng)
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

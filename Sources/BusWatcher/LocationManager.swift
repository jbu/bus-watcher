import CoreLocation

@Observable
@MainActor
final class LocationManager: NSObject {
    var nearbyStop: StopConfig? = nil
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func setup() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startMonitoring()
        default:
            break
        }
    }

    private func startMonitoring() {
        for stop in watchedStops {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                radius: 500,
                identifier: stop.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedAlways { self.startMonitoring() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let identifier = region.identifier
        let stop = watchedStops.first { $0.id == identifier }
        Task { @MainActor in
            if state == .inside {
                self.nearbyStop = stop
            } else if self.nearbyStop?.id == identifier {
                self.nearbyStop = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        let stop = watchedStops.first { $0.id == region.identifier }
        Task { @MainActor in self.nearbyStop = stop }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in
            if self.nearbyStop?.id == identifier { self.nearbyStop = nil }
        }
    }
}

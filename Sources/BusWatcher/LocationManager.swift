import CoreLocation

@Observable
@MainActor
final class LocationManager: NSObject {
    var nearbyStop: StopConfig? = nil
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocation?

    private let manager = CLLocationManager()
    private var currentStops: [StopConfig] = []

    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
    }

    func setup() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    func syncRegions(with stops: [StopConfig]) {
        currentStops = stops
        // Always clear nearbyStop when its stop is removed, regardless of auth status.
        if let nearby = nearbyStop, !stops.contains(where: { $0.id == nearby.id }) {
            nearbyStop = nil
        }
        guard manager.authorizationStatus == .authorizedAlways ||
              manager.authorizationStatus == .authorizedWhenInUse else { return }

        let targetIds = Set(stops.map(\.id))
        let currentlyMonitored = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }

        for region in currentlyMonitored where !targetIds.contains(region.identifier) {
            manager.stopMonitoring(for: region)
        }

        let monitoredIds = Set(currentlyMonitored.map(\.identifier))
        for stop in stops where !monitoredIds.contains(stop.id) {
            let region = CLCircularRegion(
                center: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                radius: 500,
                identifier: stop.id
            )
            region.notifyOnEntry = true
            region.notifyOnExit = true
            manager.startMonitoring(for: region)
            manager.requestState(for: region)
        }
    }

    func applyRegionState(_ state: CLRegionState, identifier: String) {
        let stop = currentStops.first { $0.id == identifier }
        if state == .inside {
            nearbyStop = stop
        } else if nearbyStop?.id == identifier {
            nearbyStop = nil
        }
    }

    func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedAlways || status == .authorizedWhenInUse {
                self.syncRegions(with: self.currentStops)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        let identifier = region.identifier
        Task { @MainActor in self.applyRegionState(state, identifier: identifier) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in self.currentLocation = latest }
    }
}

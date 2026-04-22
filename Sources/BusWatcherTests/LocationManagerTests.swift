import XCTest
import CoreLocation
@testable import BusWatcher

@MainActor
final class LocationManagerTests: XCTestCase {
    private let stopA = StopConfig(
        id: "stopA", lineIds: ["1"], stopId: "43000000001",
        routeLabel: "11A", stopName: "St Mary's Rd",
        latitude: 52.455, longitude: -1.954, colorToken: .blue
    )
    private let stopB = StopConfig(
        id: "stopB", lineIds: ["2"], stopId: "43000000002",
        routeLabel: "35", stopName: "York St",
        latitude: 52.459, longitude: -1.947, colorToken: .green
    )

    func test_inside_knownStop_setsNearbyStop() {
        let lm = LocationManager()
        lm.syncRegions(with: [stopA, stopB])
        lm.applyRegionState(.inside, identifier: stopA.id)
        XCTAssertEqual(lm.nearbyStop?.id, stopA.id)
    }

    func test_outside_currentNearbyStop_clearsNearbyStop() {
        let lm = LocationManager()
        lm.syncRegions(with: [stopA])
        lm.applyRegionState(.inside, identifier: stopA.id)
        lm.applyRegionState(.outside, identifier: stopA.id)
        XCTAssertNil(lm.nearbyStop)
    }

    func test_outside_differentStop_doesNotClearNearbyStop() {
        let lm = LocationManager()
        lm.syncRegions(with: [stopA, stopB])
        lm.applyRegionState(.inside, identifier: stopA.id)
        lm.applyRegionState(.outside, identifier: stopB.id)
        XCTAssertEqual(lm.nearbyStop?.id, stopA.id)
    }

    func test_inside_unknownIdentifier_doesNotSetNearbyStop() {
        let lm = LocationManager()
        lm.syncRegions(with: [stopA])
        lm.applyRegionState(.inside, identifier: "unknown-id")
        XCTAssertNil(lm.nearbyStop)
    }

    func test_syncRegions_removesNearbyStopWhenDeleted() {
        let lm = LocationManager()
        lm.syncRegions(with: [stopA, stopB])
        lm.applyRegionState(.inside, identifier: stopA.id)
        XCTAssertEqual(lm.nearbyStop?.id, stopA.id)
        lm.syncRegions(with: [stopB])
        XCTAssertNil(lm.nearbyStop)
    }
}

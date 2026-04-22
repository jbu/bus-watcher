import XCTest
@testable import BusWatcher

@MainActor
private final class MockLiveActivityController: LiveActivityManaging {
    var areActivitiesEnabled = true
    var startCalls: [(stopId: String, state: BusActivityAttributes.ContentState)] = []
    var updateCalls: [BusActivityAttributes.ContentState] = []
    var endCallCount = 0

    func start(stopId: String, state: BusActivityAttributes.ContentState) async {
        startCalls.append((stopId: stopId, state: state))
    }

    func update(_ state: BusActivityAttributes.ContentState) async {
        updateCalls.append(state)
    }

    func end() async {
        endCallCount += 1
    }
}

@MainActor
final class BusViewModelActivityTests: XCTestCase {
    private let stop = StopConfig(
        id: "test-stop-1", lineIds: ["1144"], stopId: "43000320602",
        routeLabel: "11A", stopName: "Test Stop",
        latitude: 52.455, longitude: -1.954, colorToken: .blue
    )
    private let otherStop = StopConfig(
        id: "test-stop-2", lineIds: ["35"], stopId: "43000000002",
        routeLabel: "35", stopName: "Other Stop",
        latitude: 52.459, longitude: -1.947, colorToken: .green
    )

    private func makeVM(mock: MockLiveActivityController = MockLiveActivityController()) -> BusViewModel {
        BusViewModel(activityController: mock)
    }

    func test_nearbyStarredStop_startsActivity() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        vm.starredStopIds = [stop.id]
        await vm.handleNearbyStopChanged(stop)
        XCTAssertEqual(mock.startCalls.count, 1)
        XCTAssertEqual(mock.startCalls.first?.stopId, stop.id)
        XCTAssertEqual(mock.endCallCount, 0)
    }

    func test_nearbyUnstarredStop_endsActivity() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        vm.starredStopIds = []
        await vm.handleNearbyStopChanged(stop)
        XCTAssertEqual(mock.startCalls.count, 0)
        XCTAssertEqual(mock.endCallCount, 1)
    }

    func test_nearbyNil_endsActivity() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        await vm.handleNearbyStopChanged(nil)
        XCTAssertEqual(mock.endCallCount, 1)
    }

    func test_unstarWhileNearby_endsActivity() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        vm.starredStopIds = []
        await vm.handleStarredChanged(nearbyStop: stop)
        XCTAssertEqual(mock.endCallCount, 1)
    }

    func test_unstarDifferentStop_doesNotEndActivity() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        vm.starredStopIds = [stop.id]
        // nearbyStop is `stop` (still starred); unstarring otherStop should not end the activity
        await vm.handleStarredChanged(nearbyStop: stop)
        XCTAssertEqual(mock.endCallCount, 0)
    }

    func test_updateLiveActivity_callsControllerUpdate() async {
        let mock = MockLiveActivityController()
        let vm = makeVM(mock: mock)
        await vm.updateLiveActivity(nearbyStop: stop)
        XCTAssertEqual(mock.updateCalls.count, 1)
    }
}

import XCTest
@testable import BusWatcher

@MainActor
final class StopStoreTests: XCTestCase {
    var suiteName: String!
    var defaults: UserDefaults!

    override func setUp() async throws {
        suiteName = "StopStoreTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func test_emptyDefaults_seedsFromDefaults() {
        let store = StopStore(defaults: defaults)
        XCTAssertEqual(store.stops.map(\.id), StopStore.defaultStops.map(\.id))
    }

    func test_persist_roundTrip() {
        let store1 = StopStore(defaults: defaults)
        let newStop = StopConfig(
            id: "test1", lineIds: ["999"], stopId: "43000000001",
            routeLabel: "TST", stopName: "Test Road",
            latitude: 52.0, longitude: -1.0, colorToken: .red
        )
        _ = store1.add(newStop)

        let store2 = StopStore(defaults: defaults)
        XCTAssertEqual(store2.stops.count, StopStore.defaultStops.count + 1)
        XCTAssertEqual(store2.stops.last?.id, "test1")
        XCTAssertEqual(store2.stops.last?.colorToken, .red)
    }

    func test_remove_atOffset() {
        let store = StopStore(defaults: defaults)
        let firstId = store.stops[0].id
        store.remove(at: IndexSet(integer: 0))
        XCTAssertEqual(store.stops.count, StopStore.defaultStops.count - 1)
        XCTAssertFalse(store.stops.contains { $0.id == firstId })
    }

    func test_move_reorders() {
        let store = StopStore(defaults: defaults)
        let originalFirstId = store.stops[0].id
        store.move(from: IndexSet(integer: 0), to: store.stops.count)
        XCTAssertEqual(store.stops.last?.id, originalFirstId)
    }

    func test_decodeFailure_fallsBackToDefaults() {
        defaults.set(Data("not-json".utf8), forKey: StopStore.userDefaultsKey)
        let store = StopStore(defaults: defaults)
        XCTAssertEqual(store.stops.map(\.id), StopStore.defaultStops.map(\.id))
    }

    func test_add_respectsMaxCap() {
        let store = StopStore(defaults: defaults)
        // Fill to max
        while store.stops.count < StopStore.maxStops {
            let stop = StopConfig(
                id: UUID().uuidString, lineIds: ["1"], stopId: "43000000000",
                routeLabel: "X", stopName: "X", latitude: 0, longitude: 0, colorToken: .gray
            )
            _ = store.add(stop)
        }
        XCTAssertEqual(store.stops.count, StopStore.maxStops)
        let overflow = StopConfig(
            id: "overflow", lineIds: ["1"], stopId: "x", routeLabel: "O",
            stopName: "O", latitude: 0, longitude: 0, colorToken: .gray
        )
        XCTAssertFalse(store.add(overflow))
        XCTAssertEqual(store.stops.count, StopStore.maxStops)
    }

    func test_stopById_returnsMatch() {
        let store = StopStore(defaults: defaults)
        let first = store.stops[0]
        XCTAssertEqual(store.stopById(first.id)?.id, first.id)
        XCTAssertNil(store.stopById("no-such-id"))
    }
}

import Foundation

@Observable
@MainActor
final class StopStore {
    static let defaultStops: [StopConfig] = [
        StopConfig(id: "11a", lineIds: ["1144", "179"], stopId: "43000320602",
                   routeLabel: "11A", stopName: "St Mary's Rd",
                   latitude: 52.455677, longitude: -1.954242, colorToken: .blue),
        StopConfig(id: "35",  lineIds: ["216", "1148"], stopId: "43000202601",
                   routeLabel: "35",  stopName: "Station St",
                   latitude: 52.476753, longitude: -1.898996, colorToken: .green),
        StopConfig(id: "11c", lineIds: ["1090"],        stopId: "43000412702",
                   routeLabel: "11C", stopName: "Vicarage Rd",
                   latitude: 52.429565, longitude: -1.900940, colorToken: .orange),
        StopConfig(id: "23_24", lineIds: ["150", "151"], stopId: "43000320101",
                   routeLabel: "23/24", stopName: "York St",
                   latitude: 52.459450, longitude: -1.947204, colorToken: .purple),
    ]

    static let maxStops = 20
    static let userDefaultsKey = "watchedStops"

    var stops: [StopConfig] {
        didSet { persist() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.userDefaultsKey),
           let decoded = try? JSONDecoder().decode([StopConfig].self, from: data) {
            self.stops = decoded
        } else {
            self.stops = Self.defaultStops
        }
    }

    @discardableResult
    func add(_ stop: StopConfig) -> Bool {
        guard stops.count < Self.maxStops else { return false }
        stops.append(stop)
        return true
    }

    func remove(at offsets: IndexSet) {
        stops.remove(atOffsets: offsets)
    }

    func move(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
    }

    func stopById(_ id: String) -> StopConfig? {
        stops.first { $0.id == id }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(stops) {
            defaults.set(data, forKey: Self.userDefaultsKey)
        }
    }
}

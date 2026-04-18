import Foundation

struct StopConfig: Identifiable {
    let id: String
    let lineIds: [String]
    let stopId: String
    let routeLabel: String
    let stopName: String
}

let watchedStops: [StopConfig] = [
    StopConfig(id: "11a", lineIds: ["1144", "179"], stopId: "nwmapwdt",
               routeLabel: "11A", stopName: "St Mary's Rd"),
    StopConfig(id: "35",  lineIds: ["216", "1148"], stopId: "nwmajadp",
               routeLabel: "35",  stopName: "Station St"),
    StopConfig(id: "11c", lineIds: ["1090"],        stopId: "nwmdadwt",
               routeLabel: "11C", stopName: "Vicarage Rd"),
]

struct Arrival: Codable, Identifiable, Sendable {
    let id: String
    let lineName: String?
    let destinationName: String?
    let timeToStation: Int
    let expectedArrival: String

    var minutesAway: Int { max(0, timeToStation / 60) }
}

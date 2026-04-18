import ActivityKit
import Foundation

struct BusActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var stopName: String
        var routeLabel: String
        var arrivals: [LiveArrival]
        var updatedAt: Date
    }
    let stopId: String
}

struct LiveArrival: Codable, Hashable {
    var minutesAway: Int
    var destination: String
}

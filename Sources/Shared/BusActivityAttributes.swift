import ActivityKit
import Foundation
import SwiftUI

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

func countdownText(_ minutes: Int) -> String {
    minutes == 0 ? "Due" : "\(minutes) min"
}

func countdownColor(_ minutes: Int) -> Color {
    switch minutes {
    case 0...1: return .red
    case 2...4: return .orange
    default:    return .green
    }
}

import Foundation
import SwiftUI

nonisolated(unsafe) let isoFormatter = ISO8601DateFormatter()

struct StopConfig: Identifiable {
    let id: String
    let lineIds: [String]
    let stopId: String
    let routeLabel: String
    let stopName: String
    let latitude: Double
    let longitude: Double
    let color: Color
}

let watchedStops: [StopConfig] = [
    StopConfig(id: "11a", lineIds: ["1144", "179"], stopId: "43000320602",
               routeLabel: "11A", stopName: "St Mary's Rd",
               latitude: 52.455677, longitude: -1.954242, color: .blue),
    StopConfig(id: "35",  lineIds: ["216", "1148"], stopId: "43000202601",
               routeLabel: "35",  stopName: "Station St",
               latitude: 52.476753, longitude: -1.898996, color: .green),
    StopConfig(id: "11c", lineIds: ["1090"],        stopId: "43000412702",
               routeLabel: "11C", stopName: "Vicarage Rd",
               latitude: 52.429565, longitude: -1.900940, color: .orange),
    StopConfig(id: "23_24", lineIds: ["150", "151"], stopId: "43000320101",
               routeLabel: "23/24", stopName: "York St",
               latitude: 52.459450, longitude: -1.947204, color: .purple),
]

let watchedStopById: [String: StopConfig] =
    Dictionary(uniqueKeysWithValues: watchedStops.map { ($0.id, $0) })

struct ArrivalResponse: Decodable {
    struct Inner: Decodable {
        let prediction: [Arrival]
        enum CodingKeys: String, CodingKey { case prediction = "Prediction" }
    }
    let arrayOfPrediction: Inner
    enum CodingKeys: String, CodingKey { case arrayOfPrediction = "ArrayOfPrediction" }
}

struct Arrival: Decodable, Identifiable, Sendable {
    let id: String
    let lineName: String?
    let destinationName: String?
    let expectedArrival: String?
    let scheduledArrival: String?

    var isLive: Bool { expectedArrival != nil }
    var displayArrival: String { expectedArrival ?? scheduledArrival ?? "" }
    var arrivalDate: Date? { isoFormatter.date(from: displayArrival) }
    var minutesAway: Int {
        guard let date = arrivalDate else { return 0 }
        return max(0, Int(date.timeIntervalSinceNow) / 60)
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case lineName = "LineName"
        case destinationName = "DestinationName"
        case expectedArrival = "ExpectedArrival"
        case scheduledArrival = "ScheduledArrival"
    }
}

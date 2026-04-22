import Foundation

nonisolated(unsafe) let isoFormatter = ISO8601DateFormatter()

struct StopConfig: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let lineIds: [String]
    let stopId: String
    let routeLabel: String
    let stopName: String
    let latitude: Double
    let longitude: Double
    let colorToken: StopColor
}

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

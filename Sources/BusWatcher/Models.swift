import Foundation

struct StopConfig: Identifiable {
    let id: String
    let lineIds: [String]
    let stopId: String
    let routeLabel: String
    let stopName: String
    let latitude: Double
    let longitude: Double
}

let watchedStops: [StopConfig] = [
    StopConfig(id: "11a", lineIds: ["1144", "179"], stopId: "43000320602",
               routeLabel: "11A", stopName: "St Mary's Rd",
               latitude: 52.455677, longitude: -1.954242),
    StopConfig(id: "35",  lineIds: ["216", "1148"], stopId: "43000202601",
               routeLabel: "35",  stopName: "Station St",
               latitude: 52.476753, longitude: -1.898996),
    StopConfig(id: "11c", lineIds: ["1090"],        stopId: "43000412702",
               routeLabel: "11C", stopName: "Vicarage Rd",
               latitude: 52.429565, longitude: -1.900940),
    StopConfig(id: "23_24", lineIds: ["150", "151"], stopId: "43000320101",
               routeLabel: "23/24", stopName: "York St",
               latitude: 52.459450, longitude: -1.947204),
]

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
    let timeToStation: Int
    let expectedArrival: String
    let scheduledArrival: String

    var isLive: Bool { !expectedArrival.isEmpty }
    var displayArrival: String { isLive ? expectedArrival : scheduledArrival }

    var minutesAway: Int {
        if isLive { return max(0, timeToStation / 60) }
        guard let date = ISO8601DateFormatter().date(from: scheduledArrival) else { return 0 }
        return max(0, Int(date.timeIntervalSinceNow) / 60)
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case lineName = "LineName"
        case destinationName = "DestinationName"
        case timeToStation = "TimeToStation"
        case expectedArrival = "ExpectedArrival"
        case scheduledArrival = "ScheduledArrival"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        lineName = try c.decodeIfPresent(String.self, forKey: .lineName)
        destinationName = try c.decodeIfPresent(String.self, forKey: .destinationName)
        expectedArrival = (try? c.decode(String.self, forKey: .expectedArrival)) ?? ""
        scheduledArrival = (try? c.decode(String.self, forKey: .scheduledArrival)) ?? ""
        let ttsString = (try? c.decode(String.self, forKey: .timeToStation)) ?? ""
        timeToStation = Int(ttsString) ?? 0
    }
}

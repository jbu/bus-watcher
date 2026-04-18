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

    var minutesAway: Int { max(0, timeToStation / 60) }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case lineName = "LineName"
        case destinationName = "DestinationName"
        case timeToStation = "TimeToStation"
        case expectedArrival = "ExpectedArrival"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        lineName = try c.decodeIfPresent(String.self, forKey: .lineName)
        destinationName = try c.decodeIfPresent(String.self, forKey: .destinationName)
        expectedArrival = (try? c.decode(String.self, forKey: .expectedArrival)) ?? ""
        let ttsString = (try? c.decode(String.self, forKey: .timeToStation)) ?? ""
        timeToStation = Int(ttsString) ?? 0
    }
}

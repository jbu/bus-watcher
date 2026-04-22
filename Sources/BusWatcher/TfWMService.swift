import Foundation

struct NearbyStop: Sendable, Identifiable, Hashable {
    let id: String
    let commonName: String
    let lat: Double
    let lon: Double
    let distance: Double?
    let lines: [LineInfo]
}

struct StopDetail: Sendable, Hashable {
    let id: String
    let commonName: String
    let lat: Double
    let lon: Double
    let lines: [LineInfo]
}

struct LineInfo: Sendable, Hashable, Identifiable, Codable {
    let id: String    // numeric, e.g. "3370" — the value /Line/{id}/Arrivals expects
    let name: String  // short, e.g. "55"
}

struct TfWMService: Sendable {
    private let session: URLSession
    private let base = "http://api.tfwm.org.uk"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchArrivals(for stop: StopConfig) async -> [Arrival] {
        var all: [Arrival] = []
        await withTaskGroup(of: [Arrival].self) { group in
            for lineId in stop.lineIds {
                group.addTask { await self.fetchSingleLine(lineId: lineId, stopId: stop.stopId) }
            }
            for await batch in group { all += batch }
        }
        // Deduplicate: API returns both a live and a scheduled entry per trip.
        // Normalise scheduled time to UTC epoch so timezone variants match.
        // Prefer the live entry when both exist.
        func schedKey(_ a: Arrival) -> String {
            if let sched = a.scheduledArrival, let date = isoFormatter.date(from: sched) {
                return "\(a.lineName ?? "")|\(Int(date.timeIntervalSince1970))"
            }
            return a.id
        }
        var byScheduled: [String: Arrival] = [:]
        for arrival in all {
            let key = schedKey(arrival)
            if let existing = byScheduled[key] {
                if arrival.isLive && !existing.isLive { byScheduled[key] = arrival }
            } else {
                byScheduled[key] = arrival
            }
        }
        let cutoff = Date().addingTimeInterval(-60)
        return byScheduled.values
            .filter { $0.arrivalDate.map { $0 >= cutoff } ?? false }
            .sorted { $0.minutesAway < $1.minutesAway }
            .prefix(3)
            .map { $0 }
    }

    func nearbyStops(lat: Double, lon: Double, radius: Int = 500) async -> [NearbyStop] {
        guard var comps = URLComponents(string: "\(base)/StopPoint") else { return [] }
        comps.queryItems = [
            URLQueryItem(name: "lat", value: String(lat)),
            URLQueryItem(name: "lon", value: String(lon)),
            URLQueryItem(name: "stopTypes", value: "NaptanMarkedPoint"),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "app_id", value: Secrets.appId),
            URLQueryItem(name: "app_key", value: Secrets.appKey),
            URLQueryItem(name: "formatter", value: "JSON"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await session.data(from: url),
              let wrapper = try? JSONDecoder().decode(NearbyRootResponse.self, from: data)
        else { return [] }
        let raw = wrapper.stopPointsResponse.stopPoints?.stopPoint.values ?? []
        return raw.map { NearbyStop(from: $0) }
    }

    func fetchStopDetail(stopId: String) async -> StopDetail? {
        guard var comps = URLComponents(string: "\(base)/StopPoint/\(stopId)") else { return nil }
        comps.queryItems = [
            URLQueryItem(name: "app_id", value: Secrets.appId),
            URLQueryItem(name: "app_key", value: Secrets.appKey),
            URLQueryItem(name: "formatter", value: "JSON"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await session.data(from: url),
              let wrapper = try? JSONDecoder().decode(StopDetailRoot.self, from: data)
        else { return nil }
        let sp = wrapper.stopPoint
        return StopDetail(
            id: sp.id,
            commonName: sp.commonName,
            lat: sp.lat,
            lon: sp.lon,
            lines: sp.lines?.identifier.values.map { LineInfo(id: $0.id, name: $0.name) } ?? []
        )
    }

    private func fetchSingleLine(lineId: String, stopId: String) async -> [Arrival] {
        guard var comps = URLComponents(string: "\(base)/Line/\(lineId)/Arrivals/\(stopId)") else {
            return []
        }
        comps.queryItems = [
            URLQueryItem(name: "app_id",    value: Secrets.appId),
            URLQueryItem(name: "app_key",   value: Secrets.appKey),
            URLQueryItem(name: "formatter", value: "JSON"),
        ]
        guard let url = comps.url,
              let (data, _) = try? await session.data(from: url),
              let wrapper = try? JSONDecoder().decode(ArrivalResponse.self, from: data)
        else { return [] }
        return wrapper.arrayOfPrediction.prediction
    }
}

// MARK: - Single-or-array tolerant wrapper

struct SingleOrArray<T: Decodable>: Decodable {
    let values: [T]
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([T].self) {
            self.values = array
        } else if let single = try? container.decode(T.self) {
            self.values = [single]
        } else {
            self.values = []
        }
    }
}

// MARK: - Nearby response

private struct NearbyRootResponse: Decodable {
    let stopPointsResponse: NearbyInner
    enum CodingKeys: String, CodingKey { case stopPointsResponse = "StopPointsResponse" }
}
private struct NearbyInner: Decodable {
    let stopPoints: NearbyPoints?
    enum CodingKeys: String, CodingKey { case stopPoints = "StopPoints" }
}
private struct NearbyPoints: Decodable {
    let stopPoint: SingleOrArray<RawStopPoint>
    enum CodingKeys: String, CodingKey { case stopPoint = "StopPoint" }
}
private struct RawStopPoint: Decodable {
    let id: String
    let commonName: String
    let lat: Double
    let lon: Double
    let distance: Double?
    let lines: RawLines?
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case commonName = "CommonName"
        case lat = "Lat"
        case lon = "Lon"
        case distance = "Distance"
        case lines = "Lines"
    }
}
private struct RawLines: Decodable {
    let identifier: SingleOrArray<RawLineIdentifier>
    enum CodingKeys: String, CodingKey { case identifier = "Identifier" }
}
private struct RawLineIdentifier: Decodable {
    let id: String
    let name: String
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

extension NearbyStop {
    fileprivate init(from raw: RawStopPoint) {
        self.init(
            id: raw.id,
            commonName: raw.commonName,
            lat: raw.lat,
            lon: raw.lon,
            distance: raw.distance,
            lines: raw.lines?.identifier.values.map { LineInfo(id: $0.id, name: $0.name) } ?? []
        )
    }
}

// MARK: - Stop detail response

private struct StopDetailRoot: Decodable {
    let stopPoint: RawStopPoint
    enum CodingKeys: String, CodingKey { case stopPoint = "StopPoint" }
}

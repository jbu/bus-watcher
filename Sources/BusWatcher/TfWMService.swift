import Foundation

struct TfWMService: Sendable {
    private let session = URLSession.shared
    private let base = "http://api.tfwm.org.uk"

    func fetchArrivals(for stop: StopConfig) async -> [Arrival] {
        var all: [Arrival] = []
        await withTaskGroup(of: [Arrival].self) { group in
            for lineId in stop.lineIds {
                group.addTask {
                    await self.fetchSingleLine(lineId: lineId, stopId: stop.stopId)
                }
            }
            for await batch in group {
                all += batch
            }
        }
        // Deduplicate by ScheduledArrival (API returns a live + a scheduled entry per trip).
        // Normalise to UTC epoch seconds so "19:07:48Z" and "19:07:48+01:00" match.
        // Prefer live entry when both exist.
        let iso = ISO8601DateFormatter()
        func schedKey(_ a: Arrival) -> String {
            if let date = iso.date(from: a.scheduledArrival) {
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
        func bestDate(_ a: Arrival) -> Date? {
            if let d = iso.date(from: a.expectedArrival) { return d }
            return iso.date(from: a.scheduledArrival)
        }
        return byScheduled.values
            .filter { bestDate($0).map { $0 >= cutoff } ?? false }
            .sorted { $0.minutesAway < $1.minutesAway }
            .prefix(5)
            .map { $0 }
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

import Foundation

struct TfWMService: Sendable {
    private let session = URLSession.shared
    private let base = "http://api.tfwm.org.uk"

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

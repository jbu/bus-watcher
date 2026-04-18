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
        var seen = Set<String>()
        return all
            .filter { seen.insert($0.id).inserted && $0.timeToStation >= -60 }
            .sorted { $0.timeToStation < $1.timeToStation }
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
              let arrivals = try? JSONDecoder().decode([Arrival].self, from: data)
        else { return [] }
        return arrivals
    }
}

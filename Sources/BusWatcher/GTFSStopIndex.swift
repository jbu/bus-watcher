import Foundation

struct StopRecord: Sendable, Hashable {
    let id: String
    let code: String
    let name: String
    let lat: Double
    let lon: Double
}

final class GTFSStopIndex: @unchecked Sendable {
    static let shared = GTFSStopIndex()

    private let lock = NSLock()
    private var loaded: [StopRecord]?

    init() {}

    init(records: [StopRecord]) {
        self.loaded = records
    }

    private func records() -> [StopRecord] {
        lock.lock()
        defer { lock.unlock() }
        if let loaded { return loaded }
        let parsed = Self.loadFromBundle()
        loaded = parsed
        return parsed
    }

    func search(query: String, limit: Int = 50) -> [StopRecord] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        var results: [StopRecord] = []
        for r in records() {
            if r.name.lowercased().contains(q) {
                results.append(r)
                if results.count >= limit { break }
            }
        }
        return results
    }

    func stop(byId id: String) -> StopRecord? {
        records().first { $0.id == id }
    }

    static func parse(_ text: String) -> [StopRecord] {
        var result: [StopRecord] = []
        result.reserveCapacity(15_000)
        var isFirst = true
        text.enumerateLines { line, _ in
            if isFirst { isFirst = false; return }
            guard let rec = parseRow(line) else { return }
            result.append(rec)
        }
        return result
    }

    // stop_id,stop_code,stop_name,stop_lat,stop_lon,location_type,parent_station,platform_code
    // Handles simple quoted fields (no embedded quotes, which GTFS doesn't use here).
    static func parseRow(_ line: String) -> StopRecord? {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" { inQuotes.toggle(); continue }
            if ch == "," && !inQuotes {
                fields.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        fields.append(current)
        guard fields.count >= 5 else { return nil }
        guard let lat = Double(fields[3]), let lon = Double(fields[4]) else { return nil }
        return StopRecord(id: fields[0], code: fields[1], name: fields[2], lat: lat, lon: lon)
    }

    private static func loadFromBundle() -> [StopRecord] {
        guard let url = Bundle.main.url(forResource: "stops", withExtension: "txt"),
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }
        return parse(text)
    }
}

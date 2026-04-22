import SwiftUI
import CoreLocation

struct AddStopView: View {
    @Environment(LocationManager.self) private var locationManager
    @State private var query = ""
    @State private var results: [StopRecord] = []
    @State private var nearby: [NearbyStop] = []
    @State private var nearbyLoading = false

    let onCompleted: () -> Void

    private let service = TfWMService()

    var body: some View {
        List {
            if !nearby.isEmpty || nearbyLoading {
                Section("Nearby") {
                    if nearbyLoading && nearby.isEmpty {
                        HStack { ProgressView(); Text("Looking up nearby stops…").foregroundStyle(.secondary) }
                    }
                    ForEach(nearby) { stop in
                        NavigationLink {
                            ConfigureStopView(
                                stopId: stop.id,
                                fallbackName: stop.commonName,
                                fallbackLat: stop.lat,
                                fallbackLon: stop.lon,
                                prefetchedLines: stop.lines,
                                onCompleted: onCompleted
                            )
                        } label: {
                            NearbyRow(stop: stop)
                        }
                        .accessibilityIdentifier("nearbyRow-\(stop.id)")
                    }
                }
            }

            if !query.isEmpty {
                Section("Results") {
                    if results.isEmpty {
                        Text("No matches").foregroundStyle(.secondary)
                    }
                    ForEach(results, id: \.id) { rec in
                        NavigationLink {
                            ConfigureStopView(
                                stopId: rec.id,
                                fallbackName: rec.name,
                                fallbackLat: rec.lat,
                                fallbackLon: rec.lon,
                                prefetchedLines: nil,
                                onCompleted: onCompleted
                            )
                        } label: {
                            SearchRow(rec: rec)
                        }
                        .accessibilityIdentifier("searchRow-\(rec.id)")
                    }
                }
            }
        }
        .navigationTitle("Add Stop")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Search by name")
        .task(id: query) {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            let q = query
            results = GTFSStopIndex.shared.search(query: q)
        }
        .task {
            locationManager.startUpdatingLocation()
            defer { locationManager.stopUpdatingLocation() }
            try? await Task.sleep(for: .seconds(30))
        }
        .task(id: locationManager.currentLocation?.coordinate.latitude) {
            guard let loc = locationManager.currentLocation else { return }
            nearbyLoading = true
            let fetched = await service.nearbyStops(lat: loc.coordinate.latitude,
                                                     lon: loc.coordinate.longitude,
                                                     radius: 500)
            nearby = fetched
            nearbyLoading = false
        }
    }
}

private struct NearbyRow: View {
    let stop: NearbyStop

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stop.commonName).font(.body)
            HStack(spacing: 6) {
                if let d = stop.distance {
                    Text("\(Int(d)) m").font(.caption).foregroundStyle(.secondary)
                }
                if !stop.lines.isEmpty {
                    Text(stop.lines.map(\.name).sorted().joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct SearchRow: View {
    let rec: StopRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(rec.name).font(.body)
            Text(rec.code).font(.caption).foregroundStyle(.secondary)
        }
    }
}

import SwiftUI

struct ConfigureStopView: View {
    @Environment(StopStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let stopId: String
    let fallbackName: String
    let fallbackLat: Double
    let fallbackLon: Double
    let prefetchedLines: [LineInfo]?
    let onCompleted: () -> Void

    @State private var loading = true
    @State private var stopName: String = ""
    @State private var lat: Double = 0
    @State private var lon: Double = 0
    @State private var lines: [LineInfo] = []
    @State private var selectedNames: Set<String> = []
    @State private var label: String = ""
    @State private var color: StopColor = .blue
    @State private var errorMessage: String?

    private let service = TfWMService()

    // Distinct line short-names, sorted.
    private var groupedNames: [String] {
        Array(Set(lines.map(\.name))).sorted()
    }

    private var selectedLineIds: [String] {
        lines.filter { selectedNames.contains($0.name) }.map(\.id)
    }

    var body: some View {
        Form {
            if loading {
                HStack { ProgressView(); Text("Loading lines…").foregroundStyle(.secondary) }
            } else {
                Section("Stop") {
                    Text(stopName).font(.headline)
                    Text(stopId).font(.caption).foregroundStyle(.secondary)
                }

                Section("Label") {
                    TextField("Route label", text: $label)
                        .accessibilityIdentifier("routeLabelField")
                }

                Section("Lines to watch") {
                    if groupedNames.isEmpty {
                        Text("No bus lines listed for this stop").foregroundStyle(.secondary)
                    } else {
                        ForEach(groupedNames, id: \.self) { name in
                            Toggle(name, isOn: binding(for: name))
                                .accessibilityIdentifier("lineToggle-\(name)")
                        }
                    }
                }

                Section("Color") {
                    colorPicker
                }

                if let err = errorMessage {
                    Section { Text(err).foregroundStyle(.red) }
                }
            }
        }
        .navigationTitle("Configure")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { addStop() }
                    .disabled(loading || selectedLineIds.isEmpty || label.isEmpty)
                    .accessibilityIdentifier("confirmAddButton")
            }
        }
        .task { await loadDetail() }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(StopColor.allCases, id: \.self) { c in
                    Circle()
                        .fill(c.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: c == color ? 3 : 0)
                        )
                        .onTapGesture { color = c }
                        .accessibilityIdentifier("colorSwatch-\(c.rawValue)")
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding(
            get: { selectedNames.contains(name) },
            set: { isOn in
                if isOn { selectedNames.insert(name) } else { selectedNames.remove(name) }
            }
        )
    }

    private func loadDetail() async {
        defer { loading = false }
        if let detail = await service.fetchStopDetail(stopId: stopId) {
            stopName = detail.commonName
            lat = detail.lat
            lon = detail.lon
            lines = detail.lines
        } else if let prefetched = prefetchedLines {
            stopName = fallbackName
            lat = fallbackLat
            lon = fallbackLon
            lines = prefetched
        } else {
            stopName = fallbackName
            lat = fallbackLat
            lon = fallbackLon
            lines = []
        }
        selectedNames = Set(lines.map(\.name))
        label = lines.first?.name ?? stopName
    }

    private func addStop() {
        let stop = StopConfig(
            id: UUID().uuidString,
            lineIds: selectedLineIds,
            stopId: stopId,
            routeLabel: label,
            stopName: stopName,
            latitude: lat,
            longitude: lon,
            colorToken: color
        )
        if store.add(stop) {
            onCompleted()
        } else {
            errorMessage = "You've reached the maximum of \(StopStore.maxStops) stops."
        }
    }
}

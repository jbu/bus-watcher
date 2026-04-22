import SwiftUI

@Observable
@MainActor
final class BusViewModel {
    var arrivals: [String: [Arrival]] = [:]
    var lastUpdated: Date?

    private let service = TfWMService()
    private let activityController: any LiveActivityManaging
    private var isRefreshing = false

    var starredStopIds: Set<String> = {
        if let stored = UserDefaults.standard.stringArray(forKey: "starredStops") {
            return Set(stored)
        }
        return Set(StopStore.defaultStops.map(\.id))
    }() {
        didSet { UserDefaults.standard.set(Array(starredStopIds), forKey: "starredStops") }
    }

    init(activityController: any LiveActivityManaging = DefaultLiveActivityController()) {
        self.activityController = activityController
    }

    func toggleStar(for stop: StopConfig) {
        if starredStopIds.contains(stop.id) {
            starredStopIds.remove(stop.id)
        } else {
            starredStopIds.insert(stop.id)
        }
    }

    func refresh(stops: [StopConfig]) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: (String, [Arrival]).self) { group in
            for stop in stops {
                group.addTask { (stop.id, await self.service.fetchArrivals(for: stop)) }
            }
            for await (id, result) in group {
                arrivals[id] = result
            }
        }
        lastUpdated = Date()
    }

    func handleNearbyStopChanged(_ stop: StopConfig?) async {
        if let stop, starredStopIds.contains(stop.id) {
            await startLiveActivity(for: stop)
        } else {
            await endLiveActivity()
        }
    }

    func handleStarredChanged(nearbyStop: StopConfig?) async {
        if let stop = nearbyStop, !starredStopIds.contains(stop.id) {
            await endLiveActivity()
        }
    }

    func startLiveActivity(for stop: StopConfig) async {
        await activityController.start(stopId: stop.id, state: makeState(for: stop))
    }

    func updateLiveActivity(nearbyStop: StopConfig?) async {
        guard let stop = nearbyStop else { return }
        await activityController.update(makeState(for: stop))
    }

    func endLiveActivity() async {
        await activityController.end()
    }

    private func makeState(for stop: StopConfig) -> BusActivityAttributes.ContentState {
        let liveArrivals = (arrivals[stop.id] ?? []).prefix(3).map {
            LiveArrival(minutesAway: $0.minutesAway, destination: $0.destinationName ?? "")
        }
        return BusActivityAttributes.ContentState(
            stopName: stop.stopName,
            routeLabel: stop.routeLabel,
            arrivals: Array(liveArrivals),
            updatedAt: Date()
        )
    }
}

struct ContentView: View {
    @State private var vm = BusViewModel()
    @Environment(LocationManager.self) private var locationManager
    @Environment(StopStore.self) private var store
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bus Watcher")
                                .font(.largeTitle)
                                .bold()
                            if let updated = vm.lastUpdated {
                                Text("Updated \(updated, style: .time)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            showingEditor = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("editStopsButton")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(store.stops) { stop in
                        StopCardView(
                            stop: stop,
                            arrivals: vm.arrivals[stop.id] ?? [],
                            isStarred: vm.starredStopIds.contains(stop.id),
                            onToggleStar: { vm.toggleStar(for: stop) }
                        )
                    }
                }
                .padding()
            }
            .toolbarVisibility(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showingEditor) {
            StopEditorSheet()
                .environment(store)
                .environment(locationManager)
        }
        .task {
            locationManager.setup()
            locationManager.syncRegions(with: store.stops)
            while !Task.isCancelled {
                await vm.refresh(stops: store.stops)
                await vm.updateLiveActivity(nearbyStop: locationManager.nearbyStop)
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: store.stops.map(\.id)) { _, _ in
            locationManager.syncRegions(with: store.stops)
        }
        .onChange(of: locationManager.nearbyStop?.id) { _, _ in
            Task { await vm.handleNearbyStopChanged(locationManager.nearbyStop) }
        }
        .onChange(of: vm.starredStopIds) { _, _ in
            Task { await vm.handleStarredChanged(nearbyStop: locationManager.nearbyStop) }
        }
    }
}

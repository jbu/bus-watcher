import SwiftUI
@preconcurrency import ActivityKit

@Observable
@MainActor
final class BusViewModel {
    var arrivals: [String: [Arrival]] = [:]
    var lastUpdated: Date?

    private let service = TfWMService()
    private var currentActivity: Activity<BusActivityAttributes>?
    private var isRefreshing = false

    var starredStopIds: Set<String> = {
        if let stored = UserDefaults.standard.stringArray(forKey: "starredStops") {
            return Set(stored)
        }
        return Set(watchedStops.map(\.id))
    }() {
        didSet { UserDefaults.standard.set(Array(starredStopIds), forKey: "starredStops") }
    }

    func toggleStar(for stop: StopConfig) {
        if starredStopIds.contains(stop.id) {
            starredStopIds.remove(stop.id)
        } else {
            starredStopIds.insert(stop.id)
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await withTaskGroup(of: (String, [Arrival]).self) { group in
            for stop in watchedStops {
                group.addTask { (stop.id, await self.service.fetchArrivals(for: stop)) }
            }
            for await (id, result) in group {
                arrivals[id] = result
            }
        }
        lastUpdated = Date()
    }

    func startLiveActivity(for stop: StopConfig) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endLiveActivity()
        let state = makeState(for: stop)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        currentActivity = try? Activity.request(
            attributes: BusActivityAttributes(stopId: stop.id),
            content: content
        )
    }

    func updateLiveActivity(nearbyStop: StopConfig?) async {
        guard let stop = nearbyStop, let activity = currentActivity else { return }
        let state = makeState(for: stop)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        await activity.update(content)
    }

    func endLiveActivity() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(watchedStops) { stop in
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
        .task {
            locationManager.setup()
            while !Task.isCancelled {
                await vm.refresh()
                await vm.updateLiveActivity(nearbyStop: locationManager.nearbyStop)
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .onChange(of: locationManager.nearbyStop?.id) { _, newStopId in
            Task {
                if let stopId = newStopId, let stop = watchedStopById[stopId],
                   vm.starredStopIds.contains(stopId) {
                    await vm.startLiveActivity(for: stop)
                } else {
                    await vm.endLiveActivity()
                }
            }
        }
        .onChange(of: vm.starredStopIds) { _, _ in
            Task {
                if let stop = locationManager.nearbyStop, !vm.starredStopIds.contains(stop.id) {
                    await vm.endLiveActivity()
                }
            }
        }
    }
}

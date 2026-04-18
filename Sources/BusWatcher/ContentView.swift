import SwiftUI
import Combine
import ActivityKit

@Observable
@MainActor
final class BusViewModel {
    var arrivals: [String: [Arrival]] = [:]
    var lastUpdated: Date?

    private let service = TfWMService()
    private var currentActivity: Activity<BusActivityAttributes>?

    func refresh() async {
        let stops = watchedStops
        let svc = service
        async let a = svc.fetchArrivals(for: stops[0])
        async let b = svc.fetchArrivals(for: stops[1])
        async let c = svc.fetchArrivals(for: stops[2])
        let (ra, rb, rc) = await (a, b, c)
        arrivals[stops[0].id] = ra
        arrivals[stops[1].id] = rb
        arrivals[stops[2].id] = rc
        lastUpdated = Date()
    }

    func startLiveActivity(for stop: StopConfig) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        await endLiveActivity()
        await refresh()
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
                    ForEach(watchedStops) { stop in
                        StopCardView(
                            stop: stop,
                            arrivals: vm.arrivals[stop.id] ?? []
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Bus Watcher")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let updated = vm.lastUpdated {
                        Text("Updated \(updated, style: .time)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .task {
            locationManager.setup()
            await vm.refresh()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task {
                await vm.refresh()
                await vm.updateLiveActivity(nearbyStop: locationManager.nearbyStop)
            }
        }
        .onChange(of: locationManager.nearbyStop?.id) { _, newStopId in
            Task {
                if let stop = watchedStops.first(where: { $0.id == newStopId }) {
                    await vm.startLiveActivity(for: stop)
                } else {
                    await vm.endLiveActivity()
                }
            }
        }
    }
}

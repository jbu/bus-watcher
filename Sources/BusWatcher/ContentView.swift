import SwiftUI
import Combine

@Observable
@MainActor
final class BusViewModel {
    var arrivals: [String: [Arrival]] = [:]
    var lastUpdated: Date?

    private let service = TfWMService()

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
}

struct ContentView: View {
    @State private var vm = BusViewModel()

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
            await vm.refresh()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            Task { await vm.refresh() }
        }
    }
}

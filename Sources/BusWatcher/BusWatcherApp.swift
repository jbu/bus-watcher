import SwiftUI

@main
struct BusWatcherApp: App {
    @State private var locationManager = LocationManager()
    @State private var store: StopStore

    init() {
        if ProcessInfo.processInfo.arguments.contains("-resetDefaults") {
            UserDefaults.standard.removeObject(forKey: "watchedStops")
            UserDefaults.standard.removeObject(forKey: "starredStops")
        }
        _store = State(initialValue: StopStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
                .environment(store)
        }
    }
}

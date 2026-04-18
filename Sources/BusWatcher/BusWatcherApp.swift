import SwiftUI

@main
struct BusWatcherApp: App {
    @State private var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(locationManager)
        }
    }
}

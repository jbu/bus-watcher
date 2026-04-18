// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BusWatcher",
    platforms: [.iOS(.v17)],
    products: [
        .iOSApplication(
            name: "BusWatcher",
            targets: ["BusWatcher"],
            bundleIdentifier: "uk.uther.apps.buswatcher",
            teamIdentifier: "JX8T6TSAWW",
            displayVersion: "1.0",
            bundleVersion: "1",
            supportedDeviceFamilies: [.pad, .phone],
            supportedInterfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight],
            appIcon: .placeholder(icon: .generic),
            additionalInfoPlistContentFilePath: "AdditionalInfo.plist"
        )
    ],
    targets: [
        .executableTarget(
            name: "BusWatcher",
            path: "Sources/BusWatcher"
        )
    ]
)

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SwiftUI iOS app (iOS 17+) that polls the TfWM (Transport for West Midlands) REST API for bus arrival times at a hardcoded set of stops, refreshing every 30 seconds. When the phone is within 500m of a stop, a Live Activity appears on the lock screen and Dynamic Island showing live departure countdowns.

## Build & Run

The project uses [xcodegen](https://github.com/yonaskolb/XcodeGen) — regenerate `BusWatcher.xcodeproj` (gitignored) before building. Building the `BusWatcher` target also compiles and embeds the `BusWatcherWidgets` extension:

```sh
xcodegen generate
xcodebuild -project BusWatcher.xcodeproj -target BusWatcher \
  -sdk iphonesimulator26.4 -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

The built `.app` lands at `build/Debug-iphonesimulator/BusWatcher.app` and contains `PlugIns/BusWatcherWidgets.appex`.

There are no tests currently.

## Simulator Debugging Loop

Install and run on a booted simulator, then take a screenshot to inspect the UI:

```sh
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install "iPhone 17" build/Debug-iphonesimulator/BusWatcher.app
xcrun simctl launch --terminate-running-process "iPhone 17" com.buswatcher.app
sleep 6
xcrun simctl io "iPhone 17" screenshot /tmp/buswatcher.png
```

To test the Live Activity / geofence trigger:

```sh
# Grant Always location permission
xcrun simctl privacy "iPhone 17" grant location com.buswatcher.app
# Simulate device at St Mary's Rd stop
xcrun simctl location "iPhone 17" set 52.455677,-1.954242
# Background the app to see the Dynamic Island
xcrun simctl launch "iPhone 17" com.apple.Preferences
```

To check network activity and errors:

```sh
xcrun simctl spawn "iPhone 17" log show --predicate 'process == "BusWatcher"' --last 2m
```

To verify the TfWM API directly (substitute line ID and stop ID):

```sh
curl "http://api.tfwm.org.uk/Line/1144/Arrivals/nwmapwdt?app_id=APP_ID&app_key=APP_KEY&formatter=JSON"
```

## Secrets Setup

Before building, copy `Secrets.example.swift` to `Sources/BusWatcher/Secrets.swift` and fill in TfWM API credentials (`appId`, `appKey`). `Secrets.swift` is gitignored.

## Architecture

- **`Sources/BusWatcher/Models.swift`** — `StopConfig` (stops/lines/coordinates) and `Arrival` (API response shape). `watchedStops` is the hardcoded array of three monitored stops.
- **`Sources/BusWatcher/TfWMService.swift`** — `async`/`await` network layer. Fetches per line in a `TaskGroup`, deduplicates, filters past arrivals (>60s ago), returns top 5.
- **`Sources/BusWatcher/LocationManager.swift`** — `CLLocationManager` wrapper. Registers 500m `CLCircularRegion` geofences for each stop. Sets `nearbyStop` on entry/exit and on `didDetermineState` (for the case where app launches while already inside a region).
- **`Sources/BusWatcher/ContentView.swift`** — `BusViewModel` (`@Observable`) owns the 30-second refresh cycle and the `Activity<BusActivityAttributes>` lifecycle (start/update/end). `ContentView` wires `LocationManager.nearbyStop` changes to activity lifecycle calls.
- **`Sources/Shared/BusActivityAttributes.swift`** — `ActivityAttributes` struct shared between the app and widget extension. Compiled into both targets.
- **`Sources/BusWatcherWidgets/`** — Widget extension. `BusLiveActivityWidget` provides lock screen and Dynamic Island (compact + expanded) views.
- **`Sources/BusWatcher/StopCardView.swift`** — Renders a single stop card in the main app UI.

Adding a new stop: add a `StopConfig` entry (with coordinates) to `watchedStops` in `Models.swift`, and add a corresponding `async let` fetch in `BusViewModel.refresh()`.

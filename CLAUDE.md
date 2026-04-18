# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

SwiftUI iOS app (iOS 17+) that polls the TfWM (Transport for West Midlands) REST API for bus arrival times at a hardcoded set of stops, refreshing every 30 seconds.

## Build & Run

The project uses [xcodegen](https://github.com/yonaskolb/XcodeGen) — regenerate `BusWatcher.xcodeproj` (gitignored) before building:

```sh
xcodegen generate
xcodebuild -project BusWatcher.xcodeproj -target BusWatcher \
  -sdk iphonesimulator26.4 -configuration Debug build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

The built `.app` lands at `build/Debug-iphonesimulator/BusWatcher.app`.

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

- **`Models.swift`** — `StopConfig` (which stops/lines to watch) and `Arrival` (API response shape). `watchedStops` is a hardcoded array of the three monitored stops.
- **`TfWMService.swift`** — `async`/`await` network layer. Fetches arrivals per line in a `TaskGroup`, deduplicates, filters out past arrivals (>60s ago), returns top 5 sorted by `timeToStation`.
- **`ContentView.swift`** — `BusViewModel` (`@Observable`) drives a `ScrollView` of `StopCardView`s. Refresh is triggered on `.task` (initial) and a 30-second `Timer.publish`.
- **`StopCardView.swift`** — Renders a single stop's card with its arrival list.

Adding a new stop means adding a `StopConfig` entry to `watchedStops` in `Models.swift` and a corresponding `async let` fetch in `BusViewModel.refresh()`.

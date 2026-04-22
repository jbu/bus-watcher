import ActivityKit
import SwiftUI
import WidgetKit

struct BusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BusActivityAttributes.self) { context in
            LockScreenView(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.routeLabel, systemImage: "bus.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.stopName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(context.state.arrivals, id: \.self) { arrival in
                            ArrivalLineView(arrival: arrival)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Label(context.state.routeLabel, systemImage: "bus.fill")
                    .font(.caption2.bold())
            } compactTrailing: {
                Text(context.state.arrivals.first.map { countdownText($0.minutesAway) } ?? "--")
                    .font(.caption2.bold())
                    .foregroundStyle(context.state.arrivals.first.map { countdownColor($0.minutesAway) } ?? .secondary)
            } minimal: {
                Image(systemName: "bus.fill")
            }
        }
    }
}

private struct LockScreenView: View {
    let state: BusActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("\(state.routeLabel) · \(state.stopName)", systemImage: "bus.fill")
                    .font(.caption.bold())
                Spacer()
                Text(state.updatedAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Divider()
            if state.arrivals.isEmpty {
                Text("No upcoming buses")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(state.arrivals, id: \.self) { arrival in
                    ArrivalLineView(arrival: arrival)
                }
            }
        }
        .padding(12)
    }
}

private struct ArrivalLineView: View {
    let arrival: LiveArrival

    var body: some View {
        HStack {
            Text(countdownText(arrival.minutesAway))
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(countdownColor(arrival.minutesAway))
                .frame(width: 44, alignment: .leading)
            Text(arrival.destination)
                .font(.caption)
                .lineLimit(1)
        }
    }
}


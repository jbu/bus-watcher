@preconcurrency import ActivityKit
import Foundation

@MainActor
protocol LiveActivityManaging {
    var areActivitiesEnabled: Bool { get }
    func start(stopId: String, state: BusActivityAttributes.ContentState) async
    func update(_ state: BusActivityAttributes.ContentState) async
    func end() async
}

final class DefaultLiveActivityController: LiveActivityManaging {
    private var currentActivity: Activity<BusActivityAttributes>?

    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(stopId: String, state: BusActivityAttributes.ContentState) async {
        await end()
        guard areActivitiesEnabled else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        currentActivity = try? Activity.request(
            attributes: BusActivityAttributes(stopId: stopId),
            content: content
        )
    }

    func update(_ state: BusActivityAttributes.ContentState) async {
        guard let activity = currentActivity else { return }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(60))
        await activity.update(content)
    }

    func end() async {
        await currentActivity?.end(nil, dismissalPolicy: .immediate)
        currentActivity = nil
    }
}

import Foundation
import Observation
#if os(iOS)
import ActivityKit
import WorkoutActivitySupport
#endif

@MainActor
@Observable
final class RestLiveActivity {
    static let shared = RestLiveActivity()
    var errorMessage: String?
    private var pending: Task<Void, Never>?

    func update(sessionID: UUID, profileName: String, exerciseName: String, nextSet: String, deadline: Date?) {
        #if os(iOS)
        let previous = pending
        pending = Task {
            await previous?.value
            guard UserDefaults.standard.bool(forKey: "liveActivitiesEnabled") else { return }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                errorMessage = "Live Activities are disabled in iPhone Settings."
                return
            }
            let state = WorkoutActivityAttributes.ContentState(exerciseName: exerciseName, nextSet: nextSet, restEndsAt: deadline)
            let content = ActivityContent(state: state, staleDate: deadline)
            if let activity = Activity<WorkoutActivityAttributes>.activities.first(where: { $0.attributes.sessionID == sessionID }) {
                await activity.update(content)
            } else {
                do {
                    _ = try Activity.request(attributes: WorkoutActivityAttributes(sessionID: sessionID, profileName: profileName), content: content, pushType: nil)
                    errorMessage = nil
                } catch { errorMessage = "Couldn’t start Live Activity: " + error.localizedDescription }
            }
        }
        #endif
    }

    func end(sessionID: UUID) {
        #if os(iOS)
        let previous = pending
        pending = Task {
            await previous?.value
            for activity in Activity<WorkoutActivityAttributes>.activities where activity.attributes.sessionID == sessionID {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }

    func endAll() {
        #if os(iOS)
        let previous = pending
        pending = Task {
            await previous?.value
            for activity in Activity<WorkoutActivityAttributes>.activities { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        #endif
    }

    func reconcile(activeSessionIDs: Set<UUID>) {
        #if os(iOS)
        for activity in Activity<WorkoutActivityAttributes>.activities where !activeSessionIDs.contains(activity.attributes.sessionID) {
            end(sessionID: activity.attributes.sessionID)
        }
        #endif
    }
}

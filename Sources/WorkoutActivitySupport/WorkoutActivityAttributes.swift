#if os(iOS)
import ActivityKit
import Foundation

public struct WorkoutActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var exerciseName: String
        public var nextSet: String
        public var restStartedAt: Date
        public var restEndsAt: Date?
        public init(exerciseName: String, nextSet: String, restStartedAt: Date = .now, restEndsAt: Date?) {
            self.exerciseName = exerciseName
            self.nextSet = nextSet
            self.restStartedAt = restStartedAt
            self.restEndsAt = restEndsAt
        }
    }
    public var sessionID: UUID
    public var profileName: String
    public init(sessionID: UUID, profileName: String) {
        self.sessionID = sessionID
        self.profileName = profileName
    }
}
#endif

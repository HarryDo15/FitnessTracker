import Foundation
import SwiftData

@Model
public final class WorkoutSession {
    @Attribute(.unique) public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String
    public var status: WorkoutStatus
    public var profile: Profile?
    public var gymVisit: GymVisit?
    public var restEndsAt: Date?
    /// Imported handwritten history has a known date, but no measured time or duration.
    public var isDateOnlyImport: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \ExerciseLog.session)
    public var exerciseLogs: [ExerciseLog] = []

    public var orderedLogs: [ExerciseLog] { exerciseLogs.sorted { $0.order < $1.order } }

    public init(profile: Profile, startedAt: Date = .now, notes: String = "") {
        self.id = UUID()
        self.profile = profile
        self.startedAt = startedAt
        self.notes = notes
        self.status = .active
    }
}

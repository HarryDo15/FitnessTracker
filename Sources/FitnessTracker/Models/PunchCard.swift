import Foundation
import SwiftData

@Model
public final class PunchCard {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var requiredVisits: Int
    public var startedAt: Date
    public var completedAt: Date?
    public var archivedAt: Date?
    /// Earned punches imported without inventing visit dates.
    public var carriedOverPunches: Int = 0
    public var profile: Profile?
    @Relationship(deleteRule: .nullify, inverse: \GymVisit.punchCard)
    public var visits: [GymVisit] = []
    @Relationship(deleteRule: .nullify, inverse: \Reward.punchCard)
    public var reward: Reward?

    public var progress: Int {
        // Legacy duplicate visits remain in history but cannot fill multiple slots.
        min(max(0, requiredVisits), max(0, carriedOverPunches)) +
            Set(visits.map { $0.dayKey ?? GymVisitRules.dayKey(profileID: profile?.id ?? $0.id,
                                                            date: $0.checkedInAt) }).count
    }

    public init(profile: Profile, title: String, requiredVisits: Int = 10, startedAt: Date = .now) throws {
        guard requiredVisits > 0 else { throw ModelValidationError.invalidVisitGoal }
        self.id = UUID()
        self.profile = profile
        self.title = title
        self.requiredVisits = requiredVisits
        self.startedAt = startedAt
    }
}

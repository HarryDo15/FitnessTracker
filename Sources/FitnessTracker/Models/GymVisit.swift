import Foundation
import SwiftData

@Model
public final class GymVisit {
    @Attribute(.unique) public var id: UUID
    public var checkedInAt: Date
    /// A stable profile + Gregorian local-date key; nil only on pre-feature records.
    @Attribute(.unique) public var dayKey: String?
    public var eligibleForPunch: Bool = false
    public var punchedAt: Date?
    public var profile: Profile?
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.gymVisit)
    public var session: WorkoutSession?
    public var punchCard: PunchCard?

    public init(profile: Profile, checkedInAt: Date = .now,
                session: WorkoutSession? = nil, punchCard: PunchCard? = nil,
                calendar: Calendar = .current) throws {
        guard session == nil || session?.profile?.id == profile.id,
              punchCard == nil || punchCard?.profile?.id == profile.id else {
            throw ModelValidationError.differentProfile
        }
        self.id = UUID()
        self.profile = profile
        self.checkedInAt = checkedInAt
        self.dayKey = GymVisitRules.dayKey(profileID: profile.id, date: checkedInAt, calendar: calendar)
        self.eligibleForPunch = profile.punchCardEnabled
        self.session = session
        self.punchCard = punchCard
    }
}

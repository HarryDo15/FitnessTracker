import Foundation
import SwiftData

@Model
public final class Profile {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var symbolName: String
    @Attribute(.externalStorage) public var avatarData: Data?
    public var createdAt: Date
    public var librarySeedVersion: Int
    public var punchCardEnabled: Bool = false
    public var rewardMessage: String = "You earned a treat!"
    public var gymRewardsSetupVersion: Int = 0
    public var startingValuesSeedVersion: Int = 0
    public var initialPunchesSeedVersion: Int = 0
    public var personalNameSeedVersion: Int = 0
    public var baselineWorkoutSeedVersion: Int = 0
    public var haiLibrarySeedVersion: Int = 0
    public var perSideLoadCorrectionVersion: Int = 0
    public var partialRepSeedVersion: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplate.profile)
    public var templates: [WorkoutTemplate] = []

    @Relationship(deleteRule: .cascade, inverse: \Exercise.profile)
    public var exercises: [Exercise] = []
    @Relationship(deleteRule: .cascade, inverse: \WorkoutSession.profile)
    public var sessions: [WorkoutSession] = []
    @Relationship(deleteRule: .cascade, inverse: \GymVisit.profile)
    public var gymVisits: [GymVisit] = []
    @Relationship(deleteRule: .cascade, inverse: \PunchCard.profile)
    public var punchCards: [PunchCard] = []
    @Relationship(deleteRule: .cascade, inverse: \Reward.profile)
    public var rewards: [Reward] = []

    public init(id: UUID = UUID(), name: String, symbolName: String = "person.circle", createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.createdAt = createdAt
        self.librarySeedVersion = 0
    }
}

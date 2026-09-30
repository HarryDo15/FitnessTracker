import Foundation
import SwiftData

@Model
public final class Reward {
    @Attribute(.unique) public var id: UUID
    public var title: String
    public var details: String
    public var earnedAt: Date?
    public var redeemedAt: Date?
    public var profile: Profile?
    public var punchCard: PunchCard?

    public init(profile: Profile, title: String, details: String = "", punchCard: PunchCard? = nil) throws {
        guard punchCard == nil || punchCard?.profile?.id == profile.id else {
            throw ModelValidationError.differentProfile
        }
        self.id = UUID()
        self.profile = profile
        self.title = title
        self.details = details
        self.punchCard = punchCard
    }
}

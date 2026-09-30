import Foundation
import SwiftData

@Model
public final class WorkoutTemplate {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var exerciseIDs: [UUID]
    public var setsPerExercise: Int
    public var profile: Profile?

    public init(profile: Profile, name: String, exerciseIDs: [UUID], setsPerExercise: Int = 3) {
        self.id = UUID()
        self.profile = profile
        self.name = name
        self.exerciseIDs = exerciseIDs
        self.setsPerExercise = setsPerExercise
    }
}

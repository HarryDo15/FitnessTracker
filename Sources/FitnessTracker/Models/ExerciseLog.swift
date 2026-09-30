import Foundation
import SwiftData

@Model
public final class ExerciseLog {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var notes: String
    public var targetRepMinimum: Int
    public var targetRepMaximum: Int
    public var weightIncrement: Double?
    public var loadNotes: String?
    public var muscleGroup: String?
    public var exerciseName: String
    public var unit: WeightUnit
    public var isAssisted: Bool
    public var session: WorkoutSession?
    public var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.log)
    public var sets: [SetEntry] = []

    public var orderedSets: [SetEntry] { sets.sorted { $0.order < $1.order } }

    public init(session: WorkoutSession, exercise: Exercise, order: Int,
                targetRepMinimum: Int? = nil, targetRepMaximum: Int? = nil, notes: String = "") throws {
        guard let owner = session.profile, owner.id == exercise.profile?.id else {
            throw ModelValidationError.differentProfile
        }
        guard !exercise.isArchived else { throw ModelValidationError.archivedExercise }
        let minimum = targetRepMinimum ?? exercise.targetRepMinimum
        let maximum = targetRepMaximum ?? exercise.targetRepMaximum
        guard minimum > 0, maximum >= minimum else {
            throw ModelValidationError.invalidRepRange
        }
        self.id = UUID()
        self.session = session
        self.exercise = exercise
        self.order = order
        self.targetRepMinimum = minimum
        self.targetRepMaximum = maximum
        self.weightIncrement = exercise.weightIncrement
        self.loadNotes = exercise.loadNotes
        self.notes = notes
        self.muscleGroup = exercise.muscleGroup
        self.exerciseName = exercise.name
        self.unit = exercise.unit
        self.isAssisted = exercise.isAssisted
    }
}

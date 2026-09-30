import Foundation
import SwiftData

@Model
public final class Exercise {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var muscleGroup: String
    public var equipment: String
    public var unit: WeightUnit
    public var weightIncrement: Double
    public var targetRepMinimum: Int = 8
    public var targetRepMaximum: Int = 12
    /// A starting reference, not a completed workout or a chart data point.
    public var startingWeight: Double?
    public var startingReps: Int?
    public var startingUnit: WeightUnit?
    public var startingNotes: String = ""
    /// Explains how to enter the load (for example plates only or per dumbbell).
    public var loadNotes: String = ""
    public var setupNotes: String = ""
    public var isFavorite: Bool = false
    @Attribute(.externalStorage) public var photoData: Data?
    /// Assisted exercises progress by reducing the assistance weight.
    public var isAssisted: Bool
    public var isArchived: Bool
    public var profile: Profile?

    @Relationship(deleteRule: .nullify, inverse: \ExerciseLog.exercise)
    public var logs: [ExerciseLog] = []

    public init(name: String, muscleGroup: String, equipment: String, unit: WeightUnit = .kg,
                weightIncrement: Double = 2.5, isAssisted: Bool = false, profile: Profile) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.unit = unit
        self.weightIncrement = weightIncrement
        self.isAssisted = isAssisted
        self.isArchived = false
        self.profile = profile
    }
}

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ExerciseSettingsViewModel {
    var minimum: Int
    var maximum: Int
    var increment: Double
    var errorMessage: String?
    private let exercise: Exercise
    var isValid: Bool {
        ProgressionSettings(minimumReps: minimum, maximumReps: maximum, weightIncrement: increment).isValid
    }

    init(exercise: Exercise) {
        let initialMinimum = min(100, max(1, exercise.targetRepMinimum))
        self.exercise = exercise
        minimum = initialMinimum
        maximum = min(100, max(initialMinimum, exercise.targetRepMaximum))
        increment = exercise.weightIncrement.isFinite ? min(100, max(0.05, exercise.weightIncrement)) : 2.5
    }

    func save(in context: ModelContext) -> Bool {
        guard isValid else { errorMessage = "Choose a valid rep range and an increment from 0.05 to 100."; return false }
        exercise.targetRepMinimum = minimum
        exercise.targetRepMaximum = maximum
        exercise.weightIncrement = increment
        do { try context.save(); return true }
        catch { context.rollback(); errorMessage = error.localizedDescription; return false }
    }
}

import SwiftUI

enum ExerciseStartingValues {
    static func draft(for exercise: Exercise, in unit: WeightUnit) -> SetDraft? {
        guard let weight = exercise.startingWeight, let reps = exercise.startingReps,
              let originalUnit = exercise.startingUnit,
              SetInputRules.isValid(weight: weight, reps: reps) else { return nil }
        let converted = WorkoutCalculations.convertedWeight(weight, from: originalUnit, to: unit)
        return SetDraft(weight: (converted * 100).rounded() / 100, reps: reps)
    }
}

struct StartingReferenceView: View {
    let exercise: Exercise
    let unit: WeightUnit

    var body: some View {
        if let starting = ExerciseStartingValues.draft(for: exercise, in: unit) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Starting reference").font(.headline).accessibilityAddTraits(.isHeader)
                Text("\(starting.weight.formatted()) \(unit.rawValue) × \(starting.reps) full reps")
                    .monospacedDigit()
                    .accessibilityLabel(SpokenWorkoutValue.set(weight: starting.weight, unit: unit, reps: starting.reps))
                if !exercise.startingNotes.isEmpty { Text(exercise.startingNotes).font(.subheadline) }
                Text("Saved starting values. Logged workouts take priority.")
                    .font(.caption).foregroundStyle(.secondary)
            }.fixedSize(horizontal: false, vertical: true)
        }
    }
}

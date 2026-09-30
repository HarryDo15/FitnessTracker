import Foundation

public enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg, lb
    public var id: String { rawValue }
}

public enum WorkoutStatus: String, Codable {
    case active, completed
}

public enum ModelValidationError: LocalizedError {
    case differentProfile, archivedExercise, invalidSet, invalidRepRange, invalidVisitGoal

    public var errorDescription: String? {
        switch self {
        case .differentProfile: return "Choose an exercise or record belonging to this profile."
        case .archivedExercise: return "This exercise is archived. Choose an active exercise."
        case .invalidSet: return "Enter a weight from 0 to 10,000, reps from 1 to 999, and an optional RPE from 1 to 10."
        case .invalidRepRange: return "Choose a rep range with a minimum of at least 1 and a maximum no lower than the minimum."
        case .invalidVisitGoal: return "A punch card must require at least one visit."
        }
    }
}

enum SetInputRules {
    static let maximumWeight: Double = 10_000
    static let maximumReps = 999

    static func isValid(weight: Double, reps: Int, completed: Bool = true) -> Bool {
        weight.isFinite && (0...maximumWeight).contains(weight) &&
            ((completed ? 1 : 0)...maximumReps).contains(reps)
    }

    static func adjustedReps(_ reps: Int, by change: Int) -> Int {
        // Clamp before arithmetic, including typed Int.min/Int.max values.
        min(maximumReps, max(1, min(maximumReps, max(1, reps)) + min(1, max(-1, change))))
    }

    static func adjustedWeight(_ weight: Double, by change: Double) -> Double {
        let base = weight.isFinite ? min(maximumWeight, max(0, weight)) : 0
        let step = change.isFinite ? min(maximumWeight, max(-maximumWeight, change)) : 0
        return (min(maximumWeight, max(0, base + step)) * 100).rounded() / 100
    }
}

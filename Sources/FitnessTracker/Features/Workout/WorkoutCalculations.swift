import Foundation

enum WorkoutCalculations {
    static func convertedWeight(_ weight: Double, from: WeightUnit, to: WeightUnit) -> Double {
        guard from != to else { return weight }
        return from == .kg ? weight * 2.2046226218 : weight / 2.2046226218
    }

    static func remainingSeconds(until deadline: Date?, now: Date) -> Int {
        guard let deadline else { return 0 }
        return max(0, Int(ceil(deadline.timeIntervalSince(now))))
    }

    static func duration(start: Date, end: Date) -> TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let value = max(0, Int(seconds))
        return value >= 3_600
            ? String(format: "%d:%02d:%02d", value / 3_600, value / 60 % 60, value % 60)
            : String(format: "%d:%02d", value / 60, value % 60)
    }
}

struct SetDraft {
    var weight: Double = 0
    var reps: Int = 10
    var partialReps: Int = 0
}

struct PreviousSet: Identifiable {
    let id: UUID
    let weight: Double
    let reps: Int
    var partialReps: Int = 0
    let unit: WeightUnit
}

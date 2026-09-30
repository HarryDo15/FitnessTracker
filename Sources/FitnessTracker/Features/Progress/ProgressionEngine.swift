import Foundation

struct PerformanceSet {
    let weight: Double
    let reps: Int
}

struct ExercisePerformance: Identifiable {
    let id: UUID
    let date: Date
    let sets: [PerformanceSet]
    let isAssisted: Bool
    var plannedSetCount: Int = 0

    init(id: UUID, date: Date, sets: [PerformanceSet], isAssisted: Bool, plannedSetCount: Int = 0) {
        self.id = id
        self.date = date
        self.sets = sets.filter { SetInputRules.isValid(weight: $0.weight, reps: $0.reps) }
        self.isAssisted = isAssisted
        self.plannedSetCount = max(plannedSetCount, sets.count)
    }

    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }
    var volume: Double? {
        isAssisted ? nil : sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
    var estimatedOneRM: Double? {
        guard !isAssisted else { return nil }
        return sets.filter { $0.weight > 0 }.map {
            $0.reps == 1 ? $0.weight : $0.weight * (1 + Double($0.reps) / 30)
        }.max()
    }
}

enum ProgressStatus: String {
    case progressed = "Progressed", matched = "Matched", regressed = "Regressed"
    case baseline = "First session", pending = "In progress", notLogged = "Not logged"
}

struct ProgressComparison {
    let status: ProgressStatus
    let reason: String
}

struct ProgressionSettings {
    let minimumReps: Int
    let maximumReps: Int
    let weightIncrement: Double
    var isValid: Bool {
        minimumReps > 0 && maximumReps >= minimumReps && maximumReps <= 100 &&
        weightIncrement.isFinite && weightIncrement >= 0.05 && weightIncrement <= 100
    }
}

struct ProgressionTarget {
    let weight: Double
    let reps: Int
    let changedWeight: Bool
    let addedRep: Bool

    func text(unit: WeightUnit, assisted: Bool) -> String {
        let amount = weight.formatted(.number.precision(.fractionLength(0...2)))
        let prefix = addedRep ? "Add 1 rep: " : "Try "
        return "\(prefix)\(amount) \(unit.rawValue)\(assisted ? " assistance" : "") × \(reps)"
    }
}

enum ProgressionEngine {
    /* Rules to tweak:
     - Compare completed, non-warm-up sets in the same unit and profile. ANY increase
       in peak weight, best reps at a shared weight, or total volume = progressed.
       Otherwise any decrease = regressed; equal metrics = matched. Improvements win
       when metrics disagree. During an unfinished workout, defer negative/equal flags.
     - Assisted lifts reverse weight (less assistance is better); ignore their volume
       and e1RM because body weight is unknown. Weight tolerance = 0.01 units;
       volume tolerance scales by total reps to absorb rounded kg/lb conversions.
     - Double progression: all working sets must reach the rep ceiling, with at least
       as many sets as last time (and no unfinished planned sets). Then add one increment
       to each set and reset to the rep floor; for assistance subtract, clamped at zero.
       Otherwise add one rep per set below the ceiling, holding weight steady.
     - Stalled = 3 consecutive completed comparisons without progress (4 sessions minimum).
       No-history, empty sessions and active workouts never count toward a stall.
     - Chart e1RM = best Epley estimate: weight × (1 + reps / 30); singles use weight.
       Volume = sum(weight × reps). Neither metric includes warm-ups or planned sets.
    */
    static let tolerance = 0.01
    static let stalledSessionThreshold = 3

    static func compare(_ current: ExercisePerformance, to previous: ExercisePerformance?,
                        isComplete: Bool = true) -> ProgressComparison {
        guard !current.sets.isEmpty else {
            return ProgressComparison(status: isComplete ? .notLogged : .pending,
                reason: isComplete ? "No working sets were completed for this exercise." : "Log a working set to compare.")
        }
        guard let previous, !previous.sets.isEmpty, current.isAssisted == previous.isAssisted else {
            return ProgressComparison(status: .baseline, reason: "This workout establishes your baseline.")
        }
        if let reason = improvement(current, over: previous) {
            return ProgressComparison(status: .progressed, reason: reason)
        }
        guard isComplete else {
            return ProgressComparison(status: .pending, reason: "Finish the workout for a final comparison.")
        }
        if improvement(previous, over: current) != nil {
            return ProgressComparison(status: .regressed, reason: "Below last time on one or more measures.")
        }
        return ProgressComparison(status: .matched, reason: "Matched last time’s weight, reps and volume measures.")
    }

    private static func improvement(_ current: ExercisePerformance, over previous: ExercisePerformance) -> String? {
        let currentPeak = current.isAssisted ? current.sets.map(\.weight).min()! : current.sets.map(\.weight).max()!
        let previousPeak = previous.isAssisted ? previous.sets.map(\.weight).min()! : previous.sets.map(\.weight).max()!
        if current.isAssisted ? currentPeak < previousPeak - tolerance : currentPeak > previousPeak + tolerance {
            return current.isAssisted ? "Less assistance than last time." : "More weight than last time."
        }
        for set in current.sets {
            let priorReps = previous.sets.filter { abs($0.weight - set.weight) <= tolerance }.map(\.reps).max()
            if let priorReps, set.reps > priorReps { return "More reps at the same weight." }
        }
        let volumeTolerance = tolerance * Double(max(current.totalReps, previous.totalReps))
        if let volume = current.volume, let previousVolume = previous.volume, volume > previousVolume + volumeTolerance {
            return "Higher total volume than last time."
        }
        return nil
    }

    static func targets(after performance: ExercisePerformance, settings: ProgressionSettings,
                        requiredSetCount: Int) -> [ProgressionTarget] {
        guard settings.isValid, !performance.sets.isEmpty else { return [] }
        let increase = performance.sets.count >= max(1, max(requiredSetCount, performance.plannedSetCount)) &&
            performance.sets.allSatisfy { $0.reps >= settings.maximumReps }
        return performance.sets.map { set in
            let nextWeight = increase
                ? SetInputRules.adjustedWeight(set.weight, by: performance.isAssisted ? -settings.weightIncrement : settings.weightIncrement)
                : set.weight
            let changedWeight = abs(nextWeight - set.weight) > tolerance
            let nextReps = changedWeight ? settings.minimumReps : min(settings.maximumReps, set.reps + 1)
            return ProgressionTarget(weight: nextWeight, reps: nextReps, changedWeight: changedWeight,
                                     addedRep: nextReps == set.reps + 1)
        }
    }

    static func stalledComparisons(in history: [ExercisePerformance]) -> Int {
        let sorted = history.filter { !$0.sets.isEmpty }.sorted {
            $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date
        }
        guard sorted.count > 1 else { return 0 }
        var count = 0
        for index in stride(from: sorted.count - 1, through: 1, by: -1) {
            let status = compare(sorted[index], to: sorted[index - 1]).status
            guard status == .matched || status == .regressed else { break }
            count += 1
        }
        return count
    }
}

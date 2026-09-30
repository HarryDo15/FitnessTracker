import Foundation

/// Compare full working reps only, against earlier completed sets of this same exercise/profile.
/// First-ever sets establish a baseline; assistance records reward a lower assistance weight.
enum PersonalRecords {
    static func achievements(for entry: SetEntry) -> [String] {
        guard !entry.isWarmUp, let date = entry.completedAt, let log = entry.log,
              let exercise = log.exercise, let ownerID = log.session?.profile?.id else { return [] }
        let earlier = exercise.logs.filter {
            $0.session?.profile?.id == ownerID && $0.isAssisted == log.isAssisted &&
            ($0.session?.status == .completed || $0.session?.id == log.session?.id)
        }.flatMap { other in
            other.sets.compactMap { set -> PerformanceSet? in
                guard set.id != entry.id, !set.isWarmUp, let completed = set.completedAt,
                      completed < date, SetInputRules.isValid(weight: set.weight, reps: set.reps) else { return nil }
                return PerformanceSet(weight: WorkoutCalculations.convertedWeight(set.weight, from: other.unit, to: log.unit), reps: set.reps)
            }
        }
        guard !earlier.isEmpty else { return [] }
        var records: [String] = []
        if log.isAssisted {
            if entry.weight < earlier.map(\.weight).min()! - 0.001 { records.append("Lowest assistance: \(entry.weight.formatted()) \(log.unit.rawValue)") }
        } else if entry.weight > earlier.map(\.weight).max()! + 0.001 {
            records.append("Heaviest set: \(entry.weight.formatted()) \(log.unit.rawValue)")
        }
        let matching = earlier.filter { abs($0.weight - entry.weight) < 0.01 }
        if let reps = matching.map(\.reps).max(), entry.reps > reps {
            records.append("Most reps at \(entry.weight.formatted()) \(log.unit.rawValue): \(entry.reps)")
        }
        func estimate(_ weight: Double, _ reps: Int) -> Double { reps == 1 ? weight : weight * (1 + Double(reps) / 30) }
        if !log.isAssisted, entry.weight > 0,
           estimate(entry.weight, entry.reps) > (earlier.map { estimate($0.weight, $0.reps) }.max() ?? 0) + 0.001 {
            records.append("Best estimated 1RM: \(estimate(entry.weight, entry.reps).formatted(.number.precision(.fractionLength(0...1)))) \(log.unit.rawValue)")
        }
        return records
    }
}

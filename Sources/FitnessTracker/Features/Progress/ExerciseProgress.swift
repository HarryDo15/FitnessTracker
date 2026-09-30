import Foundation

/// Adapts SwiftData records to the pure rule engine; normalize units before any comparison.
enum ExerciseProgress {
    static func performance(for log: ExerciseLog, unit: WeightUnit) -> ExercisePerformance {
        ExercisePerformance(id: log.session?.id ?? log.id, date: log.session?.startedAt ?? .distantPast,
            sets: log.orderedSets.filter { $0.completedAt != nil && !$0.isWarmUp && $0.weight.isFinite && $0.weight >= 0 && $0.reps > 0 }.map {
                PerformanceSet(weight: WorkoutCalculations.convertedWeight($0.weight, from: log.unit, to: unit), reps: $0.reps)
            }, isAssisted: log.isAssisted, plannedSetCount: log.sets.filter { !$0.isWarmUp }.count)
    }

    static func history(for exercise: Exercise, before: Date = .distantFuture) -> [ExercisePerformance] {
        guard let ownerID = exercise.profile?.id else { return [] }
        let logs = exercise.logs.filter {
            $0.session?.profile?.id == ownerID && $0.session?.status == .completed &&
            ($0.session?.startedAt ?? .distantFuture) < before && $0.isAssisted == exercise.isAssisted
        }
        // Legacy records may repeat an exercise in one session; chart/compare that session once.
        return Dictionary(grouping: logs, by: { $0.session!.id }).values.compactMap { group -> ExercisePerformance? in
            let ordered = group.sorted { $0.order < $1.order }
            guard let first = ordered.first else { return nil }
            let sets = ordered.flatMap { performance(for: $0, unit: exercise.unit).sets }
            guard !sets.isEmpty else { return nil }
            return ExercisePerformance(id: first.session!.id, date: first.session!.startedAt,
                sets: sets, isAssisted: first.isAssisted,
                plannedSetCount: ordered.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count })
        }.sorted { $0.date == $1.date ? $0.id.uuidString < $1.id.uuidString : $0.date < $1.date }
    }

    static func comparison(for log: ExerciseLog) -> ProgressComparison {
        guard let exercise = log.exercise, let session = log.session else {
            return ProgressComparison(status: .baseline, reason: "No linked exercise history.")
        }
        return ProgressionEngine.compare(performance(for: log, unit: exercise.unit),
            to: history(for: exercise, before: session.startedAt).last, isComplete: session.status == .completed)
    }

    static func targets(for log: ExerciseLog) -> [ProgressionTarget] {
        guard let exercise = log.exercise, let session = log.session else { return [] }
        let history = history(for: exercise, before: session.startedAt)
        let settings = ProgressionSettings(minimumReps: log.targetRepMinimum, maximumReps: log.targetRepMaximum,
            weightIncrement: log.weightIncrement ?? WorkoutCalculations.convertedWeight(
                exercise.weightIncrement, from: exercise.unit, to: log.unit))
        if session.status == .active {
            guard let previous = history.last else { return [] }
            let converted = ExercisePerformance(id: previous.id, date: previous.date,
                sets: previous.sets.map { PerformanceSet(weight: WorkoutCalculations.convertedWeight(
                    $0.weight, from: exercise.unit, to: log.unit), reps: $0.reps) },
                isAssisted: previous.isAssisted, plannedSetCount: previous.plannedSetCount)
            let precedingSetCount = history.count > 1 ? history[history.count - 2].sets.count : previous.sets.count
            return ProgressionEngine.targets(after: converted, settings: settings,
                                             requiredSetCount: max(previous.sets.count, precedingSetCount))
        }
        return ProgressionEngine.targets(after: performance(for: log, unit: log.unit), settings: settings,
            requiredSetCount: max(history.last?.sets.count ?? 1, log.sets.filter { !$0.isWarmUp }.count))
    }
}

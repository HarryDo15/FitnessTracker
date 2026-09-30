import Foundation

enum ProgressionChecks {
    static func run() -> Int {
        var checks = 0
        func expect(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        func performance(_ sets: [(Double, Int)], assisted: Bool = false, day: Double = 0,
                         planned: Int = 0) -> ExercisePerformance {
            ExercisePerformance(id: UUID(), date: Date(timeIntervalSince1970: day * 86_400),
                sets: sets.map { PerformanceSet(weight: $0.0, reps: $0.1) }, isAssisted: assisted,
                plannedSetCount: planned)
        }
        let baseline = performance([(60, 8), (60, 8), (60, 8)])
        let examples: ([(Double, Int)], ProgressStatus, String) -> Void = { sets, status, reason in
            expect(ProgressionEngine.compare(performance(sets), to: baseline).status == status, reason)
        }
        examples([(62.5, 6)], .progressed, "Higher peak load wins even if volume falls")
        examples([(60, 9), (60, 8), (60, 8)], .progressed, "One extra same-weight rep")
        examples([(50, 12), (50, 12), (50, 12)], .progressed, "More volume despite lower peak load")
        examples([(60, 8), (60, 8), (60, 8)], .matched, "Exact match")
        examples([(60, 7), (60, 7), (60, 7)], .regressed, "Fewer reps and less volume")
        examples([(60, 8)], .regressed, "Finished short workout loses volume")
        examples([(60, 8), (60, 8), (60, 8), (60, 8)], .progressed, "Extra working set increases volume")
        examples([(60.005, 8), (60.005, 8), (60.005, 8)], .matched, "Unit-rounding noise is not progression")
        expect(ProgressionEngine.compare(performance([]), to: baseline).status == .notLogged, "Completed empty logs are not marked in progress or regressed")
        expect(ProgressionEngine.compare(performance([]), to: baseline, isComplete: false).status == .pending, "Active empty logs are waiting for sets")
        expect(ProgressionEngine.compare(baseline, to: nil).status == .baseline, "First log is a baseline")
        expect(ProgressionEngine.compare(performance([(60, 8)]), to: baseline, isComplete: false).status == .pending,
               "An unfinished workout must not be flagged regressed")
        let assisted = performance([(30, 8)], assisted: true)
        expect(ProgressionEngine.compare(performance([(25, 8)], assisted: true), to: assisted).status == .progressed,
               "Lower assistance progresses")
        expect(ProgressionEngine.compare(performance([(35, 8)], assisted: true), to: assisted).status == .regressed,
               "Higher assistance regresses")
        expect(assisted.volume == nil && assisted.estimatedOneRM == nil, "Do not treat assistance as lifted weight")
        let settings = ProgressionSettings(minimumReps: 8, maximumReps: 12, weightIncrement: 2.5)
        let topped = performance([(60, 12), (60, 12), (60, 12)])
        let heavier = ProgressionEngine.targets(after: topped, settings: settings, requiredSetCount: 3)
        expect(heavier.count == 3 && heavier.allSatisfy { $0.weight == 62.5 && $0.reps == 8 }, "Double progression resets reps")
        let mixed = ProgressionEngine.targets(after: performance([(60, 12), (60, 10)]), settings: settings, requiredSetCount: 2)
        expect(mixed[0].weight == 60 && mixed[0].reps == 12 && mixed[1].reps == 11, "Hold top sets, add a rep to other sets")
        let short = ProgressionEngine.targets(after: performance([(60, 12)]), settings: settings, requiredSetCount: 3)
        expect(short[0].weight == 60, "One top set cannot substitute for all three sets")
        let unfinished = ProgressionEngine.targets(after: performance([(60, 12)], planned: 3), settings: settings, requiredSetCount: 1)
        expect(unfinished[0].weight == 60, "Unfinished planned sets block load increases")
        let lessAssistance = ProgressionEngine.targets(after: performance([(1, 12)], assisted: true), settings: settings, requiredSetCount: 1)
        expect(lessAssistance[0].weight == 0 && lessAssistance[0].reps == 8, "Assistance clamps at zero")
        let zeroAssistance = ProgressionEngine.targets(after: performance([(0, 12)], assisted: true), settings: settings, requiredSetCount: 1)
        expect(zeroAssistance[0].weight == 0 && zeroAssistance[0].reps == 12, "Do not reset reps if load cannot change")
        expect(ProgressionEngine.targets(after: baseline, settings: ProgressionSettings(minimumReps: 12,
            maximumReps: 8, weightIncrement: 2.5), requiredSetCount: 3).isEmpty, "Reject reversed range")
        expect(!ProgressionSettings(minimumReps: 8, maximumReps: 12, weightIncrement: .nan).isValid, "Reject invalid increment")
        let unchanged = (0..<4).map { performance([(60, 8)], day: Double($0)) }
        expect(ProgressionEngine.stalledComparisons(in: Array(unchanged.prefix(3))) == 2, "Three sessions only establish two comparisons")
        expect(ProgressionEngine.stalledComparisons(in: unchanged) == 3, "Four sessions establish three stalled comparisons")
        expect(ProgressionEngine.stalledComparisons(in: unchanged + [performance([(60, 9)], day: 4)]) == 0, "Progress clears a stall")
        expect(ProgressionEngine.stalledComparisons(in: unchanged + [performance([], day: 4)]) == 3, "Empty workouts do not affect stalls")
        expect(ProgressionEngine.stalledComparisons(in: unchanged.reversed()) == 3, "History sorted chronologically")
        expect(abs(topped.estimatedOneRM! - 84) < 0.00001, "Epley 60 × 12 gives 84")
        expect(performance([(60, 1)]).estimatedOneRM == 60, "Singles use actual weight")
        expect(topped.volume == 2160, "Volume sums all working sets")
        expect(performance([(0, 12)]).estimatedOneRM == nil, "Zero external weight does not estimate bodyweight 1RM")
        let invalid = performance([(.nan, 8), (.infinity, 10), (20, Int.max), (-10, 8)])
        expect(invalid.sets.isEmpty, "Invalid persisted sets are excluded from progression")
        expect(ProgressionEngine.compare(invalid, to: baseline).status == .notLogged, "Invalid data cannot manufacture progress")
        expect(SetInputRules.adjustedReps(Int.max, by: 1) == 999, "Rep increment cannot overflow")
        expect(SetInputRules.adjustedReps(Int.min, by: -1) == 1, "Rep decrement cannot overflow")
        expect(SetInputRules.adjustedWeight(.infinity, by: 2.5) == 2.5, "Recover from invalid typed weight")
        expect(SetInputRules.adjustedWeight(10_000, by: 2.5) == 10_000, "Clamp at supported weight limit")
        expect(!SetInputRules.isValid(weight: 20, reps: 0), "Completed sets require reps")
        expect(SetInputRules.isValid(weight: 20, reps: 0, completed: false), "Planned sets may have zero reps")
        return checks
    }
}

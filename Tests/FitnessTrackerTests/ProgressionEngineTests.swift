import XCTest
@testable import FitnessTracker

final class ProgressionEngineTests: XCTestCase {
    private func performance(_ sets: [(Double, Int)], day: Double = 0, assisted: Bool = false, planned: Int = 0) -> ExercisePerformance {
        ExercisePerformance(id: UUID(), date: Date(timeIntervalSince1970: day * 86_400),
            sets: sets.map { PerformanceSet(weight: $0.0, reps: $0.1) }, isAssisted: assisted, plannedSetCount: planned)
    }

    func testProgressionFlagsAndMixedMetrics() {
        let last = performance([(60, 8), (60, 8), (60, 8)])
        let scenarios: [([(Double, Int)], ProgressStatus)] = [
            ([(62.5, 6)], .progressed), // Weight increase wins even with less volume.
            ([(60, 9), (60, 8), (60, 8)], .progressed),
            ([(50, 12), (50, 12), (50, 12)], .progressed),
            ([(60, 8), (60, 8), (60, 8)], .matched),
            ([(60, 7), (60, 7), (60, 7)], .regressed),
            ([(60.005, 8), (60.005, 8), (60.005, 8)], .matched)
        ]
        for (sets, expected) in scenarios {
            XCTAssertEqual(ProgressionEngine.compare(performance(sets), to: last).status, expected)
        }
        XCTAssertEqual(ProgressionEngine.compare(performance([(60, 8)]), to: last, isComplete: false).status, .pending)
    }

    func testFirstWorkoutAndInvalidData() {
        XCTAssertEqual(ProgressionEngine.compare(performance([(20, 8)]), to: nil).status, .baseline)
        let invalid = performance([(.nan, 8), (.infinity, 10), (20, Int.max), (-10, 8)])
        XCTAssertTrue(invalid.sets.isEmpty)
        XCTAssertEqual(ProgressionEngine.compare(invalid, to: nil).status, .notLogged)
        XCTAssertEqual(ProgressionEngine.compare(invalid, to: nil, isComplete: false).status, .pending)
        XCTAssertNil(invalid.estimatedOneRM)
    }

    func testDoubleProgressionRequiresEverySet() {
        let settings = ProgressionSettings(minimumReps: 8, maximumReps: 12, weightIncrement: 2.5)
        let ready = ProgressionEngine.targets(after: performance([(60, 12), (60, 12), (60, 12)]),
            settings: settings, requiredSetCount: 3)
        XCTAssertTrue(ready.allSatisfy { $0.weight == 62.5 && $0.reps == 8 })
        let mixed = ProgressionEngine.targets(after: performance([(60, 12), (60, 10)]), settings: settings, requiredSetCount: 2)
        XCTAssertEqual(mixed.map(\.reps), [12, 11])
        XCTAssertTrue(mixed.allSatisfy { $0.weight == 60 })
        let incomplete = ProgressionEngine.targets(after: performance([(60, 12)], planned: 3), settings: settings, requiredSetCount: 1)
        XCTAssertEqual(incomplete.first?.weight, 60)
    }

    func testAssistanceAndStallReset() {
        XCTAssertEqual(ProgressionEngine.compare(performance([(25, 8)], assisted: true),
            to: performance([(30, 8)], assisted: true)).status, .progressed)
        let ready = ProgressionEngine.targets(after: performance([(1, 12)], assisted: true),
            settings: ProgressionSettings(minimumReps: 8, maximumReps: 12, weightIncrement: 2.5), requiredSetCount: 1)
        XCTAssertEqual(ready.first?.weight, 0)
        let stalled = (0..<4).map { performance([(60, 8)], day: Double($0)) }
        XCTAssertEqual(ProgressionEngine.stalledComparisons(in: stalled), 3)
        XCTAssertEqual(ProgressionEngine.stalledComparisons(in: Array(stalled.prefix(3))), 2)
        XCTAssertEqual(ProgressionEngine.stalledComparisons(in: stalled + [performance([(60, 9)], day: 4)]), 0)
    }

    func testStepperBoundsAndChartMetrics() {
        XCTAssertEqual(SetInputRules.adjustedReps(Int.max, by: 1), 999)
        XCTAssertEqual(SetInputRules.adjustedReps(Int.min, by: -1), 1)
        XCTAssertEqual(SetInputRules.adjustedWeight(.infinity, by: 2.5), 2.5)
        XCTAssertEqual(SetInputRules.adjustedWeight(10_000, by: 2.5), 10_000)
        XCTAssertFalse(SetInputRules.isValid(weight: 20, reps: 0))
        let result = performance([(60, 12), (60, 12), (60, 12)])
        XCTAssertEqual(result.volume, 2160)
        XCTAssertEqual(result.estimatedOneRM, 84)
    }
}

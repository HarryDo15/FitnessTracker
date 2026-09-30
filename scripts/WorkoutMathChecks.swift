import Foundation

@main
enum WorkoutMathChecks {
    static func main() {
        let start = Date(timeIntervalSince1970: 1_000)
        let deadline = start.addingTimeInterval(90)
        precondition(WorkoutCalculations.remainingSeconds(until: deadline, now: start) == 90)
        precondition(WorkoutCalculations.remainingSeconds(until: deadline, now: start.addingTimeInterval(45.2)) == 45)
        precondition(WorkoutCalculations.remainingSeconds(until: deadline, now: start.addingTimeInterval(600)) == 0)
        precondition(WorkoutCalculations.remainingSeconds(until: nil, now: start) == 0)
        let pounds = WorkoutCalculations.convertedWeight(20, from: .kg, to: .lb)
        precondition(abs(pounds - 44.092452436) < 0.0001)
        precondition(abs(WorkoutCalculations.convertedWeight(pounds, from: .lb, to: .kg) - 20) < 0.0001)
        precondition(WorkoutCalculations.convertedWeight(20, from: .kg, to: .kg) == 20)
        precondition(WorkoutCalculations.duration(start: start, end: start.addingTimeInterval(-1)) == 0)
        precondition(WorkoutCalculations.clock(90) == "1:30")
        precondition(WorkoutCalculations.clock(3_661) == "1:01:01")
        let progressionCount = ProgressionChecks.run()
        let gymCount = GymRuleChecks.run()
        print("Passed \(10 + progressionCount + gymCount) checks: workout math, progression, and gym visit/reward rules.")
    }
}

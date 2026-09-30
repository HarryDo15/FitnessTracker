import Foundation

struct WorkoutSummary {
    let setCount: Int
    let exerciseCount: Int
    let duration: TimeInterval
    /// Keep units separate; never add pounds and kilograms together.
    let volumeByUnit: [WeightUnit: Double]
    let hasAssistedSets: Bool

    init(session: WorkoutSession) {
        let logs = session.orderedLogs
        setCount = logs.reduce(0) { $0 + $1.sets.filter { $0.completedAt != nil }.count }
        exerciseCount = logs.filter { $0.sets.contains { $0.completedAt != nil } }.count
        duration = WorkoutCalculations.duration(start: session.startedAt, end: session.endedAt ?? .now)
        var volumes: [WeightUnit: Double] = [:]
        for log in logs where !log.isAssisted {
            for set in log.sets where set.completedAt != nil {
                volumes[log.unit, default: 0] += set.weight * Double(set.reps)
            }
        }
        volumeByUnit = volumes
        hasAssistedSets = logs.contains { $0.isAssisted && $0.sets.contains { $0.completedAt != nil } }
    }
}

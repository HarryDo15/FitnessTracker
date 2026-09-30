import Foundation
import SwiftData

@MainActor
enum PartialRepSeed {
    /// Promote the three explicitly recorded baseline annotations to structured partial reps once.
    /// Full reps, weights, dates, and all later workouts remain unchanged.
    static func install(profiles: [Profile]) {
        for profile in profiles where profile.partialRepSeedVersion < 1 {
            for session in profile.sessions where session.isDateOnlyImport && session.startedAt == BaselineWorkoutSeed.date {
                for log in session.exerciseLogs {
                    let count: Int
                    switch log.exerciseName {
                    case "Hamstring curl" where profile.punchCardEnabled: count = 3
                    case "Leg extension" where profile.punchCardEnabled: count = 1
                    case "Smith machine row" where !profile.punchCardEnabled: count = 1
                    default: continue
                    }
                    if let set = log.orderedSets.first, set.partialReps == 0 { set.partialReps = count }
                }
            }
            profile.partialRepSeedVersion = 1
        }
    }
}

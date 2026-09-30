import Foundation
import SwiftData

/// Convert the old total-plates convention once, before installing corrected seed data.
/// Never divide a log already labelled per side. Preserve dates, reps, IDs, and gym visits.
@MainActor
enum PerSideLoadCorrection {
    static let loadNotes = "Enter plates on ONE side only. Exclude the bar and machine weight."

    static func install(in context: ModelContext, profiles: [Profile]) throws {
        for profile in profiles where profile.perSideLoadCorrectionVersion < 1 {
            let ownerID = profile.id
            let exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == ownerID }))
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.profile?.id == ownerID }))
            for exercise in exercises {
                let smith = isSmith(exercise.name, equipment: exercise.equipment)
                let hip = profile.punchCardEnabled && isHip(exercise.name)
                // Bulgarian's bar-inclusive baseline is corrected separately in version 2 below.
                guard (smith && !isBulgarian(exercise.name)) || hip else { continue }
                if isTotalPlates(exercise.loadNotes) {
                    if let starting = exercise.startingWeight { exercise.startingWeight = starting / 2 }
                }
                exercise.loadNotes = loadNotes
                if hip && exercise.startingReps != nil {
                    exercise.startingWeight = 15
                    exercise.startingUnit = .kg
                    exercise.startingNotes = "15 kg of plates on each side."
                }
                if profile.punchCardEnabled && exercise.startingReps != nil && normalize(exercise.name).contains("smith") && normalize(exercise.name).contains("squat") {
                    exercise.startingWeight = 2.5
                    exercise.startingUnit = .kg
                    exercise.startingNotes = "2.5 kg of plates on each side."
                }
            }
            for session in sessions {
                for log in session.exerciseLogs {
                    let smith = isSmith(log.exerciseName, equipment: log.exercise?.equipment ?? "")
                    let hip = profile.punchCardEnabled && isHip(log.exerciseName)
                    guard (smith && !isBulgarian(log.exerciseName)) || hip else { continue }
                    if isTotalPlates(log.loadNotes ?? "") {
                        for set in log.sets { set.weight /= 2 }
                    }
                    log.loadNotes = loadNotes
                    if session.isDateOnlyImport && session.startedAt == BaselineWorkoutSeed.date {
                        if hip {
                            for set in log.sets {
                                set.weight = WorkoutCalculations.convertedWeight(15, from: .kg, to: log.unit)
                            }
                            log.notes = "15 kg of plates on each side."
                        } else if !profile.punchCardEnabled,
                                  let entry = HaiBaselineValues.entries.first(where: { normalize($0.name) == normalize(log.exerciseName) }) {
                            log.notes = entry.notes
                        }
                    }
                }
            }
            profile.perSideLoadCorrectionVersion = 1
        }
        // Also runs for installations that already applied version 1. Never rerun its divisions.
        for profile in profiles where profile.perSideLoadCorrectionVersion < 2 {
            if !profile.punchCardEnabled {
                let ownerID = profile.id
                let exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == ownerID }))
                for exercise in exercises where isSmith(exercise.name, equipment: exercise.equipment) && isBulgarian(exercise.name) {
                    exercise.loadNotes = loadNotes
                }
                let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.profile?.id == ownerID }))
                for session in sessions where session.isDateOnlyImport && session.startedAt == BaselineWorkoutSeed.date {
                    for log in session.exerciseLogs where isSmith(log.exerciseName, equipment: log.exercise?.equipment ?? "") && isBulgarian(log.exerciseName) {
                        for set in log.sets {
                            set.weight = WorkoutCalculations.convertedWeight(20, from: .kg, to: log.unit)
                        }
                        log.loadNotes = loadNotes
                        log.notes = "20 kg of plates on each side; bar excluded."
                    }
                }
            }
            profile.perSideLoadCorrectionVersion = 2
        }
    }

    private static func isTotalPlates(_ notes: String) -> Bool {
        notes.localizedCaseInsensitiveContains("total plates on both sides")
    }
    private static func normalize(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
    private static func isSmith(_ name: String, equipment: String) -> Bool {
        name.localizedCaseInsensitiveContains("smith") || equipment.localizedCaseInsensitiveContains("smith")
    }
    private static func isBulgarian(_ name: String) -> Bool { name.localizedCaseInsensitiveContains("bulgarian") }
    private static func isHip(_ name: String) -> Bool { normalize(name).hasPrefix("hipthrust") }
}

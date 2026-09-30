import Foundation
import SwiftData

/// One-time imports of the supplied notebook sets. No gym visits or punch credits are created.
@MainActor
enum BaselineWorkoutSeed {
    struct Entry {
        let name: String
        var aliases: [String] = []
        let muscle: String
        let equipment: String
        let sets: [(Double, Int)]
        var notes = ""
        var loadNotes = ""
        var assisted = false
    }

    static var date: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar.date(from: DateComponents(year: 2026, month: 9, day: 26, hour: 12))!
    }

    static func install(in context: ModelContext, profiles: [Profile]) throws {
        for profile in profiles where !profile.punchCardEnabled && profile.baselineWorkoutSeedVersion < 1 {
            try insert(HaiBaselineValues.entries, for: profile, in: context)
            profile.baselineWorkoutSeedVersion = 1
        }
        for profile in profiles where profile.punchCardEnabled && profile.baselineWorkoutSeedVersion < 1 {
            let entries = QiStartingValues.entries.map {
                Entry(name: $0.name, aliases: $0.aliases, muscle: $0.muscle, equipment: $0.equipment,
                      sets: [($0.weight, $0.reps)], notes: $0.notes, loadNotes: $0.loadNotes, assisted: $0.assisted)
            }
            try insert(entries, for: profile, in: context)
            profile.baselineWorkoutSeedVersion = 1
        }
    }

    static func insert(_ entries: [Entry], for profile: Profile, in context: ModelContext) throws {
        let profileID = profile.id
        var exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == profileID }))
        let session = WorkoutSession(profile: profile, startedAt: date,
            notes: "Imported starting workout — 26 September 2026. Only supplied sets are recorded. Time and duration were not recorded. Partial reps and setup details are preserved in exercise notes; only full reps count toward volume and progression.")
        session.isDateOnlyImport = true
        session.status = .completed
        session.endedAt = date
        context.insert(session)
        for (index, entry) in entries.enumerated() {
            let names = Set(([entry.name] + entry.aliases).map(normalize))
            let exercise: Exercise
            if let existing = exercises.first(where: { !$0.isArchived && names.contains(normalize($0.name)) }) {
                exercise = existing
            } else {
                exercise = Exercise(name: entry.name, muscleGroup: entry.muscle, equipment: entry.equipment,
                                    isAssisted: entry.assisted, profile: profile)
                context.insert(exercise)
                exercises.append(exercise)
            }
            if exercise.loadNotes.isEmpty { exercise.loadNotes = entry.loadNotes }
            let log = try ExerciseLog(session: session, exercise: exercise, order: index, notes: entry.notes)
            // Notebook values are kg, even if the existing exercise's display unit was changed.
            log.unit = .kg
            log.loadNotes = entry.loadNotes
            context.insert(log)
            for (setIndex, values) in entry.sets.enumerated() {
                context.insert(try SetEntry(log: log, order: setIndex, weight: values.0, reps: values.1, completedAt: date))
            }
        }
    }

    private static func normalize(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

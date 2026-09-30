import Foundation
import SwiftData

@MainActor
enum QiStartingValues {
    struct Entry {
        let name: String
        let aliases: [String]
        let muscle: String
        let equipment: String
        let weight: Double
        let reps: Int
        var notes: String = ""
        var loadNotes: String = ""
        var assisted: Bool = false
    }

    // Preserve the supplied full reps. Partials and failure describe the reference only;
    // they are never silently copied into completed sets or used to inflate progression.
    static let entries: [Entry] = [
        Entry(name: "Hamstring curl", aliases: [], muscle: "Hamstrings", equipment: "Machine",
              weight: 27.5, reps: 8, notes: "8 full reps plus 3 partial reps."),
        Entry(name: "Smith machine squat", aliases: ["Smith Squat"], muscle: "Quadriceps / Glutes", equipment: "Smith machine",
              weight: 2.5, reps: 10, notes: "2.5 kg of plates on each side.",
              loadNotes: "Enter plates on ONE side only. Exclude the bar and machine weight."),
        Entry(name: "Hip thrust", aliases: ["Hip Thrusts"], muscle: "Glutes", equipment: "Weighted hip thrust",
              weight: 15, reps: 12, notes: "15 kg of plates on each side.",
              loadNotes: "Enter plates on ONE side only. Exclude the bar and machine weight."),
        Entry(name: "Bulgarian split squat", aliases: ["Bulgarian Split squats"], muscle: "Quadriceps / Glutes", equipment: "Dumbbells / Bench",
              weight: 5, reps: 10, notes: "Two 5 kg dumbbells (10 kg combined), for 10 reps.",
              loadNotes: "Enter weight per dumbbell. Two dumbbells are used."),
        Entry(name: "Leg extension", aliases: ["Leg Ext."], muscle: "Quadriceps", equipment: "Machine",
              weight: 20, reps: 9, notes: "9 full reps plus 1 partial rep."),
        Entry(name: "Glute machine isolation kick-back", aliases: ["Glute machine kick back"], muscle: "Glutes", equipment: "Machine",
              weight: 61, reps: 13),
        Entry(name: "Shoulder bench press", aliases: ["Shoulder bench press (40 degree)"], muscle: "Shoulders", equipment: "Dumbbells / Bench",
              weight: 6, reps: 10, loadNotes: "Bench angle: 40 degrees."),
        Entry(name: "Tricep extension", aliases: ["Tricep ext."], muscle: "Triceps", equipment: "Cable",
              weight: 5, reps: 10),
        Entry(name: "Tricep overhead extension", aliases: ["Tricep overhead ext"], muscle: "Triceps", equipment: "Cable",
              weight: 2.5, reps: 10),
        Entry(name: "Lateral raise", aliases: ["Lat raise"], muscle: "Shoulders", equipment: "Dumbbells",
              weight: 2.5, reps: 12),
        Entry(name: "Lat pull-down", aliases: [], muscle: "Back", equipment: "Cable",
              weight: 13, reps: 7, notes: "Reported at failure."),
        Entry(name: "Cable row", aliases: ["Row"], muscle: "Back", equipment: "Cable",
              weight: 10, reps: 10),
        Entry(name: "Assisted pull-up", aliases: [], muscle: "Back / Biceps", equipment: "Assisted pull-up machine",
              weight: 42.5, reps: 11, assisted: true)
    ]

    static func install(in context: ModelContext, profiles: [Profile]) throws {
        for profile in profiles where profile.punchCardEnabled && profile.startingValuesSeedVersion < 1 {
            let profileID = profile.id
            var exercises = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == profileID }))
            for entry in entries {
                let names = Set(([entry.name] + entry.aliases).map(normalized))
                let exercise: Exercise
                if let existing = exercises.first(where: { names.contains(normalized($0.name)) }) {
                    exercise = existing
                } else {
                    exercise = Exercise(name: entry.name, muscleGroup: entry.muscle, equipment: entry.equipment,
                                        isAssisted: entry.assisted, profile: profile)
                    context.insert(exercise)
                    exercises.append(exercise)
                }
                // Don't overwrite an explicitly configured starting reference on upgrade.
                if exercise.startingWeight == nil && exercise.startingReps == nil {
                    exercise.startingWeight = entry.weight
                    exercise.startingReps = entry.reps
                    exercise.startingUnit = .kg
                    exercise.startingNotes = entry.notes
                }
                if exercise.loadNotes.isEmpty { exercise.loadNotes = entry.loadNotes }
            }
            if profile.name.caseInsensitiveCompare("Girlfriend") == .orderedSame { profile.name = "Qi" }
            profile.startingValuesSeedVersion = 1
        }
    }

    private static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

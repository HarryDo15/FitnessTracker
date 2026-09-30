import Foundation
import SwiftData

@MainActor
enum HaiExerciseLibrary {
    // Keep distinct machine, cable, dumbbell, and bench-angle variants separate.
    static let entries: [(name: String, muscle: String, equipment: String, aliases: [String])] = [
        ("Seated dumbbell curl", "Biceps", "Dumbbells / Bench", []),
        ("Bayesian curl", "Biceps", "Cable", []),
        ("Tricep overhead extension", "Triceps", "Cable", []),
        ("Tricep single-arm rope extension", "Triceps", "Cable / Rope", []),
        ("Lat pull-down", "Back", "Cable", []),
        ("Machine row", "Back", "Machine", []),
        ("Barbell chest-supported row", "Back", "Barbell / Bench", []),
        ("Cable single-arm pull-down", "Back", "Cable", []),
        ("Seated cable row", "Back", "Cable", ["Cable row"]),
        ("Smith machine row", "Back", "Smith machine", []),
        ("Rear delt cable fly", "Rear deltoids", "Cable", []),
        ("Dumbbell shoulder press (50 degrees)", "Shoulders", "Dumbbells / Bench", []),
        ("Cable lateral raise", "Shoulders", "Cable", []),
        ("Smith flat bench press", "Chest / Triceps", "Smith machine / Bench", []),
        ("Incline dumbbell press", "Chest / Triceps", "Dumbbells / Bench", []),
        ("Smith incline chest press", "Chest / Triceps", "Smith machine / Bench", []),
        ("Chest fly (Sulek)", "Chest", "Cable", []),
        ("Smith machine Bulgarian split squat", "Quadriceps / Glutes", "Smith machine / Bench", []),
        ("Smith Romanian deadlift", "Hamstrings / Glutes", "Smith machine", []),
        ("Smith machine squat", "Quadriceps / Glutes", "Smith machine", []),
        ("Smith calf raise", "Calves", "Smith machine", [])
    ]

    static func install(in context: ModelContext, profiles: [Profile]) throws {
        for profile in profiles where !profile.punchCardEnabled && profile.haiLibrarySeedVersion < 1 {
            let ownerID = profile.id
            var owned = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == ownerID }))
            for entry in entries {
                let names = Set(([entry.name] + entry.aliases).map { $0.lowercased() })
                guard !owned.contains(where: { names.contains($0.name.lowercased()) }) else { continue }
                let exercise = Exercise(name: entry.name, muscleGroup: entry.muscle, equipment: entry.equipment, profile: profile)
                context.insert(exercise)
                owned.append(exercise)
            }
            profile.haiLibrarySeedVersion = 1
        }
    }
}

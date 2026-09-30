import Foundation
import SwiftData

@MainActor
public enum SeedData {
    private static let library: [(String, String, String, Bool)] = [
        ("Smith machine squat", "Quadriceps / Glutes", "Smith machine", false),
        ("Bulgarian split squat", "Quadriceps / Glutes", "Dumbbells / Bench", false),
        ("Romanian deadlift", "Hamstrings / Glutes", "Barbell", false),
        ("Leg extension", "Quadriceps", "Machine", false),
        ("Hamstring curl", "Hamstrings", "Machine", false),
        ("Glute machine isolation kick-back", "Glutes", "Machine", false),
        ("Shoulder bench press", "Shoulders", "Dumbbells / Bench", false),
        ("Tricep extension", "Triceps", "Cable", false),
        ("Tricep overhead extension", "Triceps", "Cable", false),
        ("Lateral raise", "Shoulders", "Dumbbells", false),
        ("Lat pull-down", "Back", "Cable", false),
        ("Cable row", "Back", "Cable", false),
        ("Assisted pull-up", "Back / Biceps", "Assisted pull-up machine", true),
        ("Bicep-standing curls", "Biceps", "Dumbbells", false),
        ("Bench press", "Chest / Triceps", "Barbell / Bench", false)
    ]

    /// Seed once per profile. Renaming or deleting an exercise never recreates it on launch.
    public static func install(in context: ModelContext, includePersonalValues: Bool = true) throws {
        var profiles = try context.fetch(FetchDescriptor<Profile>())
        if profiles.isEmpty {
            profiles = [Profile(name: "Hai"), Profile(name: "Girlfriend", symbolName: "person.crop.circle")]
            for profile in profiles { context.insert(profile) }
        }
        for profile in profiles where profile.gymRewardsSetupVersion < 1 {
            // One-time identification of the original girlfriend seed; later renames are safe.
            profile.punchCardEnabled = profile.name == "Girlfriend" || profile.symbolName == "person.crop.circle"
            profile.gymRewardsSetupVersion = 1
        }
        for profile in profiles where profile.librarySeedVersion < 1 {
            for (name, muscle, equipment, assisted) in library {
                let exercise = Exercise(name: name, muscleGroup: muscle, equipment: equipment,
                                        isAssisted: assisted, profile: profile)
                context.insert(exercise)
            }
            profile.librarySeedVersion = 1
        }
        if includePersonalValues {
            try PerSideLoadCorrection.install(in: context, profiles: profiles)
            for profile in profiles where profile.personalNameSeedVersion < 1 {
                // Rename the original default in place, preserving its ID and all history.
                if profile.name == "Me" && !profile.punchCardEnabled { profile.name = "Hai" }
                profile.personalNameSeedVersion = 1
            }
            try QiStartingValues.install(in: context, profiles: profiles)
            try HaiExerciseLibrary.install(in: context, profiles: profiles)
            try BaselineWorkoutSeed.install(in: context, profiles: profiles)
            try GymVisitService(context: context).importStartingPunches(profiles: profiles, target: 7)
        }
        try context.save()
    }
}

import SwiftData

@MainActor
public enum ModelContainerFactory {
    public static func make(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Profile.self, Exercise.self, WorkoutSession.self, ExerciseLog.self,
            SetEntry.self, GymVisit.self, PunchCard.self, Reward.self, WorkoutTemplate.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory,
                                               cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

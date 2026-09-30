import Foundation
import SwiftData

@MainActor
public enum PreviewData {
    public static func makeContainer() throws -> ModelContainer {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context, includePersonalValues: false)
        let profiles = try context.fetch(FetchDescriptor<Profile>(sortBy: [SortDescriptor(\Profile.name)]))
        for (index, profile) in profiles.enumerated() {
            let date = Date.now.addingTimeInterval(-Double(index + 1) * 86_400)
            let session = WorkoutSession(profile: profile, startedAt: date, notes: "Sample workout")
            context.insert(session)
            session.status = .completed
            session.endedAt = date.addingTimeInterval(3_600)
            for (order, exercise) in profile.exercises.sorted(by: { $0.name < $1.name }).prefix(3).enumerated() {
                let log = try ExerciseLog(session: session, exercise: exercise, order: order)
                context.insert(log)
                for setIndex in 0..<3 {
                    context.insert(try SetEntry(log: log, order: setIndex,
                        weight: Double(20 + index * 10), reps: 10 + setIndex, rpe: 8,
                        completedAt: date.addingTimeInterval(Double((order * 3 + setIndex + 1) * 120))))
                }
            }
            let card = try PunchCard(profile: profile, title: "Ten visits")
            context.insert(card)
            context.insert(try Reward(profile: profile, title: "Date night", punchCard: card))
            context.insert(try GymVisit(profile: profile, checkedInAt: date, session: session, punchCard: card))
        }
        try context.save()
        return container
    }
}

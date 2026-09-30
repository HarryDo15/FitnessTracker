import SwiftUI
import SwiftData

@MainActor
private struct ProgressPreviewHost: View {
    let container: ModelContainer
    let profile: Profile
    let exercise: Exercise
    let dashboard: Bool

    init(dashboard: Bool) {
        self.dashboard = dashboard
        do {
            let previewContainer = try ModelContainerFactory.make(inMemory: true)
            let context = previewContainer.mainContext
            let previewProfile = Profile(name: "Hai")
            context.insert(previewProfile)
            let previewExercise = Exercise(name: "Bench press", muscleGroup: "Chest", equipment: "Barbell", profile: previewProfile)
            context.insert(previewExercise)
            for (index, reps) in [8, 10, 12, 12, 12, 12].enumerated() {
                let date = Date.now.addingTimeInterval(Double(index - 7) * 86_400 * 3)
                let session = WorkoutSession(profile: previewProfile, startedAt: date)
                context.insert(session)
                session.status = .completed
                session.endedAt = date.addingTimeInterval(3600)
                let log = try ExerciseLog(session: session, exercise: previewExercise, order: 0)
                context.insert(log)
                for order in 0..<3 {
                    context.insert(try SetEntry(log: log, order: order, weight: 60, reps: reps, completedAt: date))
                }
            }
            try context.save()
            container = previewContainer
            profile = previewProfile
            exercise = previewExercise
        } catch { fatalError("Progress preview failed: \(error)") }
    }

    var body: some View {
        NavigationStack {
            if dashboard { ProgressDashboardView(profileID: profile.id) }
            else { ExerciseDetailView(exercise: exercise) }
        }.modelContainer(container)
    }
}

#Preview("Progress charts & next target") { ProgressPreviewHost(dashboard: false) }
#Preview("Stalled exercise dashboard") { ProgressPreviewHost(dashboard: true) }
#Preview("Charts — dark, largest text") {
    ProgressPreviewHost(dashboard: false).preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}

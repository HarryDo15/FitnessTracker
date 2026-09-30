import SwiftUI
import SwiftData

struct PreviewHost<Content: View>: View {
    private let container: ModelContainer
    @State private var selection: ProfileContext
    private let content: Content

    @MainActor init(activeWorkout: Bool = false, @ViewBuilder content: () -> Content) {
        do {
            let container = try PreviewData.makeContainer()
            self.container = container
            let selection = ProfileContext(defaults: nil)
            selection.restore(from: try container.mainContext.fetch(FetchDescriptor<Profile>(
                sortBy: [SortDescriptor(\Profile.createdAt)])))
            if activeWorkout, let profile = try container.mainContext.fetch(FetchDescriptor<Profile>()).first(where: {
                $0.id == selection.selectedProfileID
            }), let exercise = profile.exercises.first(where: { $0.name == "Bench press" }) {
                let model = WorkoutViewModel(profile: profile, context: container.mainContext)
                model.start(now: .now.addingTimeInterval(-600))
                model.add(exercise)
                if let log = model.session?.exerciseLogs.first {
                    model.updateDraft(SetDraft(weight: 30, reps: 10), for: log)
                    model.logSet(for: log)
                }
            }
            _selection = State(initialValue: selection)
            self.content = content()
        } catch {
            fatalError("Preview data failed: \(error)")
        }
    }

    var body: some View { content.modelContainer(container).environment(selection) }
}

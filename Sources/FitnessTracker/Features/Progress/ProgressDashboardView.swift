import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Query private var exercises: [Exercise]
    init(profileID: UUID) {
        _exercises = Query(filter: #Predicate<Exercise> {
            $0.profile?.id == profileID && !$0.isArchived
        }, sort: \Exercise.name)
    }

    var body: some View {
        let stalled = exercises.compactMap { exercise -> (Exercise, Int)? in
            let count = ProgressionEngine.stalledComparisons(in: ExerciseProgress.history(for: exercise))
            return count >= ProgressionEngine.stalledSessionThreshold ? (exercise, count) : nil
        }.sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 > $1.1 }
        List {
            Section {
                Text("\(stalled.count) stalled exercises").font(.title2.bold())
                Text("Three or more consecutive completed sessions without improvement over the preceding session. Needs at least four sessions of history.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("Needs attention") {
                if stalled.isEmpty {
                    Text("No stalls detected. Keep logging completed workouts to build your history.")
                        .foregroundStyle(.secondary)
                }
                ForEach(stalled, id: \.0.id) { exercise, count in
                    NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exercise.name).font(.headline)
                            Text("\(count) sessions without progress").font(.subheadline).foregroundStyle(.secondary)
                        }.frame(minHeight: 52)
                    }
                }
            }
        }.navigationTitle("Progress")
    }
}

import SwiftUI

struct ExerciseOrderView: View {
    @Environment(\.dismiss) private var dismiss
    let model: WorkoutViewModel
    @State private var ids: [UUID]
    init(model: WorkoutViewModel) {
        self.model = model
        _ids = State(initialValue: model.session?.orderedLogs.map(\.id) ?? [])
    }
    var body: some View {
        List {
            Text("Drag exercises into the order you want to perform them.").font(.subheadline).foregroundStyle(.secondary)
            ForEach(ids, id: \.self) { id in
                Text(model.session?.exerciseLogs.first { $0.id == id }?.exerciseName ?? "Exercise").frame(minHeight: 44)
            }.onMove { ids.move(fromOffsets: $0, toOffset: $1) }
        }
        #if os(iOS)
        .environment(\.editMode, .constant(.active))
        #endif
        .navigationTitle("Reorder exercises")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save") { if model.reorder(ids) { dismiss() } } }
        }
    }
}

struct ExerciseSubstitutionView: View {
    @Environment(\.dismiss) private var dismiss
    let log: ExerciseLog
    let model: WorkoutViewModel
    var substituted: (ExerciseLog) -> Void = { _ in }
    @State private var search = ""
    var body: some View {
        let choices = model.profile.exercises.filter { exercise in
            !exercise.isArchived && !(model.session?.exerciseLogs.contains { $0.exercise?.id == exercise.id } ?? false) &&
                (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search))
        }.sorted { a, b in
            let aMatches = a.muscleGroup == log.exercise?.muscleGroup
            let bMatches = b.muscleGroup == log.exercise?.muscleGroup
            return aMatches != bMatches ? aMatches : a.name < b.name
        }
        List {
            Text("Completed sets stay with \(log.exerciseName). The replacement uses its own history and targets.")
                .font(.subheadline).foregroundStyle(.secondary)
            ForEach(choices) { exercise in
                Button {
                    if let replacement = model.substitute(log, with: exercise) { substituted(replacement); dismiss() }
                } label: {
                    VStack(alignment: .leading) {
                        Text(exercise.name).font(.headline)
                        Text(exercise.muscleGroup + " · " + exercise.equipment).font(.caption).foregroundStyle(.secondary)
                    }.frame(minHeight: 52)
                }
            }
            if choices.isEmpty { ContentUnavailableView.search(text: search) }
        }
        .searchable(text: $search)
        .navigationTitle("Swap exercise")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
    }
}

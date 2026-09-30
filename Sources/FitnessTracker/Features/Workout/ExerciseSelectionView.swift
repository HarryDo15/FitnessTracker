import SwiftUI
import SwiftData

struct ExerciseSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]
    @State private var search = ""
    @State private var showingEditor = false
    let profileID: UUID
    let session: WorkoutSession
    private var addedIDs: Set<UUID> { Set(session.exerciseLogs.compactMap { $0.exercise?.id }) }
    let add: (Exercise) -> Void

    init(session: WorkoutSession, profileID: UUID, add: @escaping (Exercise) -> Void) {
        self.profileID = profileID
        _exercises = Query(filter: #Predicate<Exercise> {
            $0.profile?.id == profileID && !$0.isArchived
        }, sort: \Exercise.name)
        self.session = session
        self.add = add
    }

    var body: some View {
        let filtered = exercises.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.isFavorite != $1.isFavorite ? $0.isFavorite : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        NavigationStack {
            List {
                if exercises.isEmpty {
                    ContentUnavailableView("No active exercises", systemImage: "dumbbell",
                        description: Text("This profile has no active exercises in its library."))
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
                ForEach(filtered) { exercise in
                    Button { add(exercise) } label: {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text((exercise.isFavorite ? "★ " : "") + exercise.name).font(.headline).foregroundStyle(.primary)
                                Text(exercise.equipment).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: addedIDs.contains(exercise.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.title2)
                        }.frame(minHeight: 56).contentShape(Rectangle())
                    }.disabled(addedIDs.contains(exercise.id))
                    .accessibilityLabel("\(exercise.name), \(addedIDs.contains(exercise.id) ? "added" : "add exercise")")
                }
            }
            .searchable(text: $search, prompt: "Find an exercise")
            .navigationTitle("Add exercises")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { ProfilePicker() }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingEditor = true } label: { Label("Create exercise", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack { ExerciseEditorView(profileID: profileID) }
            }
            .safeAreaInset(edge: .bottom) {
                Button { dismiss() } label: {
                    Text("Done").frame(maxWidth: .infinity, minHeight: 52)
                }.buttonStyle(.borderedProminent).controlSize(.large).padding().background(.regularMaterial)
            }
        }
    }
}

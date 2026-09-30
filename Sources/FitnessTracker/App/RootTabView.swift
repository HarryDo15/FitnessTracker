import SwiftUI
import SwiftData

public struct RootTabView: View {
    @Environment(ProfileContext.self) private var selection
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.modelContext) private var context
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @AppStorage("restoreGeneration") private var restoreGeneration = 0

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Outside navigation stacks, so the picker remains visible on pushed screens.
            let headerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout())
            headerLayout {
                Text("Fitness Tracker").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                ProfilePicker()
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Settings and backup")
            }.padding()
            if let id = selection.selectedProfileID {
                TabView {
                    NavigationStack {
                        WorkoutHomeView(profileID: id)
                    }.tabItem { Label("Today", systemImage: "dumbbell") }
                    NavigationStack { HistoryView(profileID: id) }
                        .tabItem { Label("History", systemImage: "clock") }
                    NavigationStack { ExerciseLibraryView(profileID: id) }
                        .tabItem { Label("Exercises", systemImage: "list.bullet") }
                    NavigationStack { ProgressDashboardView(profileID: id) }
                        .tabItem { Label("Progress", systemImage: "chart.xyaxis.line") }
                    NavigationStack { GymRewardsHomeView() }
                        .tabItem { Label("Rewards", systemImage: "gift") }
                }
                .id("\(id)-\(restoreGeneration)") // Clears the previous profile's navigation and transient view state.
            } else if profiles.isEmpty {
                ContentUnavailableView {
                    Label("No profiles", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Create your two profiles to start tracking workouts.")
                } actions: {
                    Button("Create profiles") {
                        do { try SeedData.install(in: context) }
                        catch { errorMessage = error.localizedDescription }
                    }.buttonStyle(.borderedProminent)
                }
            } else {
                ProgressView("Loading profile")
            }
        }
        .sheet(isPresented: $showingSettings) { NavigationStack { AppSettingsView() } }
        .task {
            if let sessions = try? context.fetch(FetchDescriptor<WorkoutSession>()) {
                RestLiveActivity.shared.reconcile(activeSessionIDs: Set(sessions.filter { $0.status == .active }.map(\.id)))
            }
        }
        .onChange(of: profiles.map(\.id), initial: true) { _, _ in selection.restore(from: profiles) }
        .alert("Couldn’t create profiles", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

private struct ExerciseLibraryView: View {
    @Query private var exercises: [Exercise]
    @State private var showingEditor = false
    @State private var search = ""
    @State private var favoritesOnly = false
    let profileID: UUID
    init(profileID: UUID) {
        self.profileID = profileID
        _exercises = Query(filter: #Predicate<Exercise> {
            $0.profile?.id == profileID && !$0.isArchived
        }, sort: \Exercise.name)
    }
    var body: some View {
        List {
            Toggle("Favorites only", isOn: $favoritesOnly)
            ForEach(exercises.filter { (!favoritesOnly || $0.isFavorite) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)) }
                .sorted { $0.isFavorite != $1.isFavorite ? $0.isFavorite : $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { exercise in
            NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                VStack(alignment: .leading) {
                    Text((exercise.isFavorite ? "★ " : "") + exercise.name)
                    Text("\(exercise.muscleGroup) · \(exercise.equipment) · \(exercise.unit.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        }.searchable(text: $search, prompt: "Find an exercise").navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingEditor = true } label: { Label("Add exercise", systemImage: "plus").frame(minHeight: 44) }
                }
            }
            .sheet(isPresented: $showingEditor) {
                NavigationStack { ExerciseEditorView(profileID: profileID) }
            }
            .overlay {
                if exercises.isEmpty {
                    ContentUnavailableView("No active exercises", systemImage: "dumbbell",
                        description: Text("Tap Add exercise to create one for this profile."))
                }
            }
    }
}

#Preview { PreviewHost { RootTabView() } }

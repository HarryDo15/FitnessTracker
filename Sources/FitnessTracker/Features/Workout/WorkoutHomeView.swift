import SwiftUI
import SwiftData

struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [Profile]

    init(profileID: UUID) {
        _profiles = Query(filter: #Predicate<Profile> { $0.id == profileID })
    }

    var body: some View {
        if let profile = profiles.first {
            WorkoutFlowView(profile: profile, context: context).id(profile.id)
        } else {
            ContentUnavailableView("Profile unavailable", systemImage: "person.crop.circle",
                description: Text("Choose a profile with the picker above."))
        }
    }
}

@MainActor
struct WorkoutFlowView: View {
    @State private var model: WorkoutViewModel
    @State private var showingExercises = false
    @State private var showingTemplates = false
    @State private var savingTemplate = false
    @State private var reordering = false
    @State private var trainingTogether = false

    init(profile: Profile, context: ModelContext) {
        _model = State(initialValue: WorkoutViewModel(profile: profile, context: context))
    }

    var body: some View {
        Group {
            if trainingTogether {
                Text("Train Together is open").foregroundStyle(.secondary)
            } else if let completed = model.finishedSession {
                WorkoutSummaryView(session: completed, done: model.dismissSummary)
            } else if let session = model.session {
                workout(session)
            } else {
                ScrollView {
                  VStack(spacing: 24) {
                    Image(systemName: "dumbbell.fill").font(.system(size: 64)).foregroundStyle(.tint).accessibilityHidden(true)
                    Text("Ready, \(model.profile.name)?").font(.largeTitle.bold())
                    Text("See last time’s numbers. Log today’s progress.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button { model.start() } label: {
                        Label("Start Workout", systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.borderedProminent).controlSize(.large)
                    if model.lastWorkout != nil {
                        Button { model.repeatLastWorkout() } label: {
                            Label("Repeat last workout", systemImage: "arrow.clockwise").frame(maxWidth: .infinity, minHeight: 52)
                        }.buttonStyle(.bordered)
                    }
                    Button { showingTemplates = true } label: {
                        Label("Workout templates", systemImage: "list.clipboard").frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.bordered)
                  }.padding()
                }
            }
        }
        .navigationTitle(model.finishedSession != nil ? "Workout complete" : "Today")
        .task { model.restore() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { trainingTogether = true } label: { Label("Train together", systemImage: "person.2.fill") }
            }
        }
        .sheet(isPresented: Binding(get: { trainingTogether }, set: { value in
            if !value { model.restore() }; trainingTogether = value
        })) { NavigationStack { TogetherWorkoutHost() } }
        .sheet(isPresented: $reordering) { NavigationStack { ExerciseOrderView(model: model) } }
        .sheet(isPresented: $showingTemplates) {
            NavigationStack { TemplateListView(profile: model.profile, start: { model.start(template: $0) }) }
        }
        .sheet(isPresented: $savingTemplate) {
            NavigationStack { TemplateEditorView(profile: model.profile, session: model.session) }
        }
        .sheet(isPresented: $showingExercises) {
            if let session = model.session {
                ExerciseSelectionView(session: session, profileID: model.profile.id) { exercise in
                    model.add(exercise)
                }
            }
        }
        .alert("Couldn’t save workout", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "Please try again.") }
    }

    private func workout(_ session: WorkoutSession) -> some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    HStack {
                        Label("In progress", systemImage: "record.circle")
                        Spacer()
                        Text(WorkoutCalculations.clock(WorkoutCalculations.duration(
                            start: session.startedAt, end: timeline.date))).monospacedDigit()
                    }.font(.subheadline).foregroundStyle(.secondary)
                }
                if session.exerciseLogs.isEmpty {
                    ContentUnavailableView("Add your first exercise", systemImage: "dumbbell",
                        description: Text("Your previous weights and reps will be ready to go."))
                }
                if let message = model.recordMessage { RecordCelebrationView(message: message) { model.recordMessage = nil } }
                Button { reordering = true } label: { Label("Reorder exercises", systemImage: "arrow.up.arrow.down").frame(minHeight: 44) }
                    .disabled(session.exerciseLogs.count < 2)
                ForEach(session.orderedLogs) { log in
                    ExerciseSetCard(log: log, model: model)
                }
                Button("Save as template") { savingTemplate = true }
                    .frame(minHeight: 44).disabled(session.exerciseLogs.isEmpty)
                Button { model.finish() } label: {
                    Label("Finish Workout", systemImage: "checkmark.flag.fill")
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(!session.exerciseLogs.contains { $0.sets.contains { $0.completedAt != nil } })
                if !session.exerciseLogs.contains(where: { $0.sets.contains { $0.completedAt != nil } }) {
                    Button(role: .destructive) { model.discardEmptyWorkout() } label: {
                        Text("Discard empty workout").frame(maxWidth: .infinity, minHeight: 48)
                    }.buttonStyle(.bordered)
                }
            }.padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                if model.canUndoLastSet {
                    Button { model.undoLastSet() } label: { Label("Undo last set", systemImage: "arrow.uturn.backward").frame(minHeight: 44) }
                }
                if let deadline = session.restEndsAt {
                    RestTimerView(deadline: deadline, extend: { model.extendRest() }, skip: model.skipRest)
                }
                Button { showingExercises = true } label: {
                    Label("Add Exercises", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }.buttonStyle(.borderedProminent).controlSize(.large)
            }.padding(.horizontal).padding(.vertical, 8).background(.regularMaterial)
        }
    }
}

#Preview("Active workout") { PreviewHost(activeWorkout: true) { RootTabView() } }
#Preview("Workout — dark, largest text") {
    PreviewHost(activeWorkout: true) { RootTabView() }.preferredColorScheme(.dark).dynamicTypeSize(.accessibility5)
}

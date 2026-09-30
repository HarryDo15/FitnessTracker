import SwiftUI
import SwiftData

struct TogetherWorkoutHost: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    var body: some View {
        if profiles.count >= 2 {
            TogetherWorkoutView(profiles: Array(profiles.prefix(2)), context: context)
        } else {
            ContentUnavailableView("Two profiles needed", systemImage: "person.2",
                description: Text("Train Together needs both profiles on this device."))
                .toolbar { Button("Close") { dismiss() } }
        }
    }
}

@MainActor
private struct TogetherWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: TogetherWorkoutViewModel
    @State private var choosing = false
    @State private var matchingPartner = true
    @State private var confirmFinish = false

    init(profiles: [Profile], context: ModelContext) {
        _model = State(initialValue: TogetherWorkoutViewModel(profiles: profiles, context: context))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if model.finished {
                    Label("Workouts saved", systemImage: "checkmark.circle.fill").font(.title.bold())
                    ForEach(model.models, id: \.profile.id) { workout in
                        Text("\(workout.profile.name): \(workout.finishedSession.map { WorkoutSummary(session: $0).setCount } ?? 0) completed sets")
                    }
                    Button("Done") { dismiss() }.buttonStyle(.borderedProminent).frame(minHeight: 52)
                } else {
                    Text("Take turns on the same exercise. Each person keeps their own sets and history.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    ForEach(model.models, id: \.profile.id) { workout in
                        Button { model.selectedProfileID = workout.profile.id } label: {
                            HStack {
                                ProfileAvatarView(data: workout.profile.avatarData, symbolName: workout.profile.symbolName, size: 36).accessibilityHidden(true)
                                Text(workout.profile.name).font(.headline)
                                Spacer()
                                if model.selectedProfileID == workout.profile.id { Label("Your turn", systemImage: "checkmark.circle.fill") }
                            }.frame(minHeight: 52)
                        }.buttonStyle(.bordered)
                        if let deadline = workout.session?.restEndsAt {
                            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                                Text("\(workout.profile.name)’s rest: \(WorkoutCalculations.clock(Double(WorkoutCalculations.remainingSeconds(until: deadline, now: timeline.date))))")
                                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                        if let message = workout.recordMessage { RecordCelebrationView(message: workout.profile.name + ": " + message) { workout.recordMessage = nil } }
                        if let error = workout.errorMessage { Text(error).foregroundStyle(.red) }
                    }
                    let current = model.current
                    if let session = current.session {
                        Menu {
                            ForEach(session.orderedLogs) { log in
                                Button(log.exerciseName) { model.select(log, for: current) }
                            }
                            Button("Add a shared exercise") { matchingPartner = true; choosing = true }
                            Button("Choose exercise just for \(current.profile.name)") { matchingPartner = false; choosing = true }
                        } label: {
                            Label("Choose exercise", systemImage: "list.bullet").frame(maxWidth: .infinity, minHeight: 48)
                        }.buttonStyle(.borderedProminent)
                        if let log = model.currentLog {
                            ExerciseSetCard(log: log, model: current, onLogged: model.nextTurn, onSubstituted: { replacement in
                                model.selectedLogIDs[current.profile.id] = replacement.id
                            }).id(log.id)
                        } else {
                            ContentUnavailableView("Choose \(current.profile.name)’s exercise", systemImage: "dumbbell",
                                description: Text("Choose a shared exercise, or pick an alternative just for this person. We won’t copy another profile’s weights."))
                        }
                        if model.currentLog == nil {
                            Button("Choose \(current.profile.name)’s exercise") { matchingPartner = false; choosing = true }
                                .buttonStyle(.borderedProminent).frame(minHeight: 48)
                        }
                        if current.canUndoLastSet { Button("Undo \(current.profile.name)’s last set") { current.undoLastSet() }.frame(minHeight: 44) }
                        if let deadline = session.restEndsAt {
                            RestTimerView(deadline: deadline, extend: { current.extendRest() }, skip: current.skipRest)
                        }
                    }
                    Button("Switch turn") { model.nextTurn() }.frame(minHeight: 48).buttonStyle(.bordered)
                    Button("Finish both workouts") { confirmFinish = true }.frame(minHeight: 52).buttonStyle(.borderedProminent)
                }
            }.padding()
        }
        .navigationTitle("Train together")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        .task { model.start() }
        .sheet(isPresented: $choosing) {
            if let session = model.current.session {
                ExerciseSelectionView(session: session, profileID: model.current.profile.id, allowExisting: true) { exercise in
                    model.choose(exercise, for: model.current, matchPartner: matchingPartner)
                }
            }
        }
        .confirmationDialog("Finish both workouts?", isPresented: $confirmFinish, titleVisibility: .visible) {
            Button("Finish and save") { model.finish() }
        } message: { Text("Completed sets are saved separately. Empty workouts are discarded.") }
    }
}

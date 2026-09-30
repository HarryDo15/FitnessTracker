import Foundation
import SwiftUI
import SwiftData

struct HistoryView: View {
    @State private var editingSet: SetEntry?
    @Query private var sessions: [WorkoutSession]

    init(profileID: UUID) {
        _sessions = Query(filter: #Predicate<WorkoutSession> { $0.profile?.id == profileID },
                          sort: \WorkoutSession.startedAt, order: .reverse)
    }

    var body: some View {
        List(sessions) { session in
            NavigationLink {
                List {
                    if !session.notes.isEmpty {
                        Section("Workout notes") { Text(session.notes) }
                    }
                    ForEach(session.orderedLogs) { log in
                        Section(log.exerciseName) {
                            if !log.notes.isEmpty { Text(log.notes).font(.subheadline) }
                            if let notes = log.loadNotes, !notes.isEmpty { Text(notes).font(.caption).foregroundStyle(.secondary) }
                            if log.sets.isEmpty { Text("No sets logged").foregroundStyle(.secondary) }
                            ForEach(log.orderedSets) { set in
                                Button { editingSet = set } label: {
                                VStack(alignment: .leading) {
                                    Text("\(set.weight, specifier: "%.1f") \(log.unit.rawValue) × \(set.reps)")
                                    if let rpe = set.rpe { Text("RPE \(rpe, specifier: "%.1f")").font(.caption) }
                                    if let date = set.completedAt, !session.isDateOnlyImport {
                                        Text(date, style: .time).font(.caption).foregroundStyle(.secondary)
                                    } else if set.completedAt == nil { Text("Planned").font(.caption) }
                                }.accessibilityElement(children: .combine)
                                }.buttonStyle(.plain).frame(minHeight: 44).accessibilityHint("Double tap to edit this set")
                            }
                        }
                    }
                }.navigationTitle("Workout")
                    .overlay {
                        if session.exerciseLogs.isEmpty {
                            ContentUnavailableView("No exercises yet", systemImage: "dumbbell",
                                description: Text("Return to Today to continue this workout."))
                        }
                    }
            } label: {
                VStack(alignment: .leading) {
                    Text(session.startedAt, style: .date)
                    if session.isDateOnlyImport { Text("Imported baseline").font(.caption) }
                    Text("\(session.exerciseLogs.count) exercises · \(session.status.rawValue)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }.navigationTitle("History")
            .sheet(item: $editingSet) { entry in NavigationStack { SetEditorView(entry: entry) } }
            .overlay {
                if sessions.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock",
                        description: Text("Start your first workout in Today. Your sessions will appear here."))
                }
            }
    }
}

import SwiftUI
import Charts

struct ExerciseDetailView: View {
    let exercise: Exercise
    @ScaledMetric(relativeTo: .body) private var chartHeight = 200.0
    @State private var showingEditor = false

    var body: some View {
        let history = ExerciseProgress.history(for: exercise)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let photo = exercise.photoData { ExercisePhotoView(data: photo, exerciseName: exercise.name) }
                if ExerciseStartingValues.draft(for: exercise, in: exercise.unit) != nil {
                    StartingReferenceView(exercise: exercise, unit: exercise.unit)
                }
                if !exercise.setupNotes.isEmpty {
                    Label(exercise.setupNotes, systemImage: "wrench.adjustable").font(.subheadline)
                }
                if !exercise.loadNotes.isEmpty {
                    Text(exercise.loadNotes).font(.subheadline).foregroundStyle(.secondary)
                }
                NavigationLink { ExerciseSettingsView(exercise: exercise) } label: {
                    Label("\(exercise.targetRepMinimum)–\(exercise.targetRepMaximum) reps · \(exercise.weightIncrement.formatted()) \(exercise.unit.rawValue) increment",
                          systemImage: "slider.horizontal.3").frame(minHeight: 48)
                }.buttonStyle(.bordered)
                if let latest = history.last {
                    ProgressBadge(comparison: ProgressionEngine.compare(latest,
                        to: history.count > 1 ? history[history.count - 2] : nil))
                    let targets = ProgressionEngine.targets(after: latest,
                        settings: ProgressionSettings(minimumReps: exercise.targetRepMinimum,
                            maximumReps: exercise.targetRepMaximum, weightIncrement: exercise.weightIncrement),
                        requiredSetCount: history.count > 1 ? history[history.count - 2].sets.count : latest.sets.count)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next workout").font(.title3.bold())
                        ForEach(Array(targets.enumerated()), id: \.offset) { index, target in
                            Text("Set \(index + 1): \(target.text(unit: exercise.unit, assisted: exercise.isAssisted))")
                        }
                    }
                }
                if history.isEmpty {
                    ContentUnavailableView("No completed workouts yet", systemImage: "chart.xyaxis.line",
                        description: Text("Log this exercise and finish a workout to see your progress."))
                } else if exercise.isAssisted {
                    Text("Estimated 1RM and lifted volume aren’t available for assisted exercises without body weight. Track assistance and reps instead.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Total reps over time").font(.title3.bold())
                    Chart(history) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Reps", point.totalReps))
                        PointMark(x: .value("Date", point.date), y: .value("Reps", point.totalReps))
                    }.frame(height: chartHeight)
                        .accessibilityLabel("Total repetitions over time for \(exercise.name)")
                        .accessibilityHint("Exact values are available in Session data below.")
                    Text("Lowest assistance (\(exercise.unit.rawValue))").font(.title3.bold())
                    Chart(history) { point in
                        if let assistance = point.sets.map(\.weight).min() {
                            LineMark(x: .value("Date", point.date), y: .value("Assistance", assistance))
                            PointMark(x: .value("Date", point.date), y: .value("Assistance", assistance))
                        }
                    }.frame(height: chartHeight)
                        .accessibilityLabel("Lowest assistance over time, in \(exercise.unit.rawValue)")
                        .accessibilityHint("Exact values are available in Session data below.")
                } else {
                    Text("Estimated 1RM (\(exercise.unit.rawValue))").font(.title3.bold())
                    if history.contains(where: { $0.estimatedOneRM != nil }) {
                        Chart(history) { point in
                            if let estimate = point.estimatedOneRM {
                                LineMark(x: .value("Date", point.date), y: .value("Estimated 1RM", estimate))
                                PointMark(x: .value("Date", point.date), y: .value("Estimated 1RM", estimate))
                            }
                        }.frame(height: chartHeight)
                            .accessibilityLabel("Estimated one repetition maximum over time, in \(exercise.unit.rawValue)")
                            .accessibilityHint("Exact values are available in Session data below.")
                    } else {
                        Text("Log a set with a positive weight to estimate 1RM.").foregroundStyle(.secondary)
                    }
                    Text("Epley estimate from your best working set; an estimate, not a tested max.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Total volume (\(exercise.unit.rawValue) × reps)").font(.title3.bold())
                    Chart(history) { point in
                        if let volume = point.volume {
                            LineMark(x: .value("Date", point.date), y: .value("Volume", volume))
                            PointMark(x: .value("Date", point.date), y: .value("Volume", volume))
                        }
                    }.frame(height: chartHeight)
                        .accessibilityLabel("Total volume over time, in \(exercise.unit.rawValue) times repetitions")
                        .accessibilityHint("Exact values are available in Session data below.")
                    Text("Completed working sets only. All weights are converted to \(exercise.unit.rawValue).")
                        .font(.caption).foregroundStyle(.secondary)
                }
                DisclosureGroup("Session data") {
                    ForEach(history.reversed()) { point in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(point.date, style: .date).font(.headline)
                            Text("\(point.sets.count) working sets · \(point.totalReps) reps")
                            if point.isAssisted, let assistance = point.sets.map(\.weight).min() {
                                Text("Lowest assistance: \(assistance.formatted()) \(exercise.unit.rawValue)")
                            }
                            if let estimate = point.estimatedOneRM {
                                Text("Estimated 1RM: \(estimate.formatted(.number.precision(.fractionLength(0...1)))) \(exercise.unit.rawValue)")
                            }
                            if let volume = point.volume {
                                Text("Volume: \(volume.formatted(.number.precision(.fractionLength(0...1)))) \(exercise.unit.rawValue) × reps")
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                            .accessibilityElement(children: .combine)
                    }
                }
            }.padding()
        }.navigationTitle(exercise.name)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEditor = true }.disabled(exercise.profile == nil)
                }
            }
            .sheet(isPresented: $showingEditor) {
                if let profile = exercise.profile {
                    NavigationStack { ExerciseEditorView(profileID: profile.id, exercise: exercise) }
                }
            }
    }
}

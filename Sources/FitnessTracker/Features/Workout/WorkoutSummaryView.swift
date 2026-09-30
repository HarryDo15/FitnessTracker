import SwiftUI
import SwiftData

struct WorkoutSummaryView: View {
    let session: WorkoutSession
    let done: () -> Void

    var body: some View {
        let summary = WorkoutSummary(session: session)
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(.green).accessibilityHidden(true)
                Text("Workout saved").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text(session.profile?.name ?? "").foregroundStyle(.secondary)
                VStack(spacing: 20) {
                    metric("Completed sets", value: "\(summary.setCount)")
                    metric("Exercises", value: "\(summary.exerciseCount)")
                    metric("Duration", value: session.isDateOnlyImport ? "Not recorded" : WorkoutCalculations.clock(summary.duration))
                    if summary.volumeByUnit.isEmpty {
                        metric("Total volume", value: "0")
                    }
                    ForEach(WeightUnit.allCases) { unit in
                        if let volume = summary.volumeByUnit[unit] {
                            metric("Total volume (\(unit.rawValue))", value: volume.formatted(.number.precision(.fractionLength(0...1))))
                        }
                    }
                }.padding().background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
                Text("Volume = weight × reps across completed sets.")
                    .font(.caption).foregroundStyle(.secondary)
                if summary.hasAssistedSets {
                    Text("Assisted sets count toward your sets, but assistance weight is excluded from volume.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(session.orderedLogs) { log in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(log.exerciseName).font(.headline)
                        ProgressBadge(comparison: ExerciseProgress.comparison(for: log))
                        ForEach(Array(ExerciseProgress.targets(for: log).enumerated()), id: \.offset) { index, target in
                            Text("Next set \(index + 1): \(target.text(unit: log.unit, assisted: log.isAssisted))")
                                .font(.subheadline)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding()
                        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                }
            }.padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: done) { Text("Done").frame(maxWidth: .infinity, minHeight: 52) }
                .buttonStyle(.borderedProminent).controlSize(.large).padding().background(.regularMaterial)
        }
    }

    private func metric(_ label: String, value: String) -> some View {
        AccessibleMetricRow(label: label, value: value)
    }
}

#Preview {
    PreviewHost { SummaryPreview() }
}

private struct SummaryPreview: View {
    @Query private var sessions: [WorkoutSession]
    var body: some View {
        if let session = sessions.first { WorkoutSummaryView(session: session, done: {}) }
    }
}

import SwiftUI

@MainActor
struct ExerciseSetCard: View {
    let log: ExerciseLog
    let model: WorkoutViewModel
    @State private var editingSet: SetEntry?
    @FocusState private var isEditing: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var draft: SetDraft { model.draft(for: log) }
    private var completed: [SetEntry] { log.orderedSets.filter { $0.completedAt != nil } }
    private var weight: Binding<Double> {
        Binding(get: { draft.weight }, set: {
            var value = draft; value.weight = $0; model.updateDraft(value, for: log)
        })
    }
    private var reps: Binding<Int> {
        Binding(get: { draft.reps }, set: {
            var value = draft; value.reps = $0; model.updateDraft(value, for: log)
        })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(log.exerciseName).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            if let photo = log.exercise?.photoData {
                ExercisePhotoView(data: photo, exerciseName: log.exerciseName, maximumHeight: 180)
            }
            if let notes = log.exercise?.setupNotes, !notes.isEmpty {
                Label(notes, systemImage: "wrench.adjustable").font(.subheadline)
            }
            ProgressBadge(comparison: ExerciseProgress.comparison(for: log))
            if let exercise = log.exercise {
                NavigationLink { ExerciseDetailView(exercise: exercise) } label: {
                    Label("Progress & targets", systemImage: "chart.xyaxis.line").frame(minHeight: 44)
                }
            }
            let previous = model.previousSets(for: log)
            if previous.isEmpty {
                if let exercise = log.exercise, ExerciseStartingValues.draft(for: exercise, in: log.unit) != nil {
                    StartingReferenceView(exercise: exercise, unit: log.unit)
                } else {
                    Text("First workout for this exercise. Set your starting weight and aim for \(log.targetRepMinimum)–\(log.targetRepMaximum) reps.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LAST TIME").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(Array(previous.enumerated()), id: \.element.id) { index, set in
                        Text("\(index + 1).  \(set.weight, specifier: "%.2f") \(set.unit.rawValue) × \(set.reps)")
                            .font(.subheadline).monospacedDigit()
                            .accessibilityLabel("Last time, set \(index + 1): \(SpokenWorkoutValue.set(weight: set.weight, unit: set.unit, reps: set.reps))")
                    }
                }
            }
            if log.isAssisted {
                Text("Weight is assistance. Less assistance means more work.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(completed.enumerated()), id: \.element.id) { index, set in
                Button { editingSet = set } label: {
                AccessibleMetricRow(label: "Set \(index + 1) completed",
                    value: "\(set.weight.formatted()) \(log.unit.rawValue) × \(set.reps)")
                    .accessibilityLabel("Set \(index + 1) completed")
                    .accessibilityValue(SpokenWorkoutValue.set(weight: set.weight, unit: log.unit, reps: set.reps))
                }.buttonStyle(.plain).frame(minHeight: 44).accessibilityHint("Double tap to edit this set")
            }
            Divider()
            Text("Set \(completed.count + 1)").font(.headline)
            let targets = ExerciseProgress.targets(for: log)
            let workingSetCount = completed.filter { !$0.isWarmUp }.count
            if !targets.isEmpty {
                let target = targets[min(workingSetCount, targets.count - 1)]
                VStack(alignment: .leading, spacing: 8) {
                    Text(target.text(unit: log.unit, assisted: log.isAssisted)).font(.subheadline.bold())
                    Button {
                        model.updateDraft(SetDraft(weight: (target.weight * 100).rounded() / 100, reps: target.reps), for: log)
                    } label: { Text("Use target").frame(minHeight: 44) }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Use target for \(log.exerciseName)")
                }
            }
            VStack(spacing: 12) {
                weightControl
                repsControl
            }
            Button {
                isEditing = false
                model.logSet(for: log)
            } label: {
                Label("Log Set \(completed.count + 1)", systemImage: "checkmark")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!SetInputRules.isValid(weight: draft.weight, reps: draft.reps))
            .accessibilityLabel("Log set \(completed.count + 1) for \(log.exerciseName)")
            .accessibilityHint("Saves this set and starts three minutes of rest.")
            if !SetInputRules.isValid(weight: draft.weight, reps: draft.reps) {
                Text("Enter a weight from 0 to 10,000 and reps from 1 to 999.").font(.caption).foregroundStyle(.primary)
            }
        }
        .padding().background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 20))
        .sheet(item: $editingSet) { entry in
            NavigationStack { SetEditorView(entry: entry, onChange: model.skipRest) }
        }
    }

    private var weightControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Weight (\(log.unit.rawValue))").font(.subheadline.bold())
            let loadNotes = log.loadNotes ?? log.exercise?.loadNotes ?? ""
            if !loadNotes.isEmpty { Text(loadNotes).font(.caption).foregroundStyle(.secondary) }
            inputLayout {
                adjustmentButton("Decrease weight", symbol: "minus") {
                    weight.wrappedValue = SetInputRules.adjustedWeight(draft.weight, by: -increment)
                }
                TextField("Weight", value: weight, format: .number.precision(.fractionLength(0...2)))
                    .focused($isEditing)
                    .gymNumberInput(decimal: true)
                    .accessibilityLabel("Weight in \(log.unit.rawValue)")
                    .accessibilityAdjustableAction { direction in
                        if direction == .increment { weight.wrappedValue = SetInputRules.adjustedWeight(draft.weight, by: increment) }
                        if direction == .decrement { weight.wrappedValue = SetInputRules.adjustedWeight(draft.weight, by: -increment) }
                    }
                adjustmentButton("Increase weight", symbol: "plus") {
                    weight.wrappedValue = SetInputRules.adjustedWeight(draft.weight, by: increment)
                }
            }
        }
    }

    private var increment: Double {
        if let snapshot = log.weightIncrement, snapshot.isFinite, snapshot > 0 { return snapshot }
        let value = log.exercise?.weightIncrement ?? 2.5
        guard value.isFinite, value > 0 else { return 2.5 }
        return WorkoutCalculations.convertedWeight(value, from: log.exercise?.unit ?? log.unit, to: log.unit)
    }

    private var repsControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reps").font(.subheadline.bold())
            inputLayout {
                adjustmentButton("Decrease reps", symbol: "minus") { reps.wrappedValue = SetInputRules.adjustedReps(draft.reps, by: -1) }
                TextField("Reps", value: reps, format: .number)
                    .focused($isEditing)
                    .gymNumberInput(decimal: false).accessibilityLabel("Repetitions")
                    .accessibilityAdjustableAction { direction in
                        if direction == .increment { reps.wrappedValue = SetInputRules.adjustedReps(draft.reps, by: 1) }
                        if direction == .decrement { reps.wrappedValue = SetInputRules.adjustedReps(draft.reps, by: -1) }
                    }
                adjustmentButton("Increase reps", symbol: "plus") { reps.wrappedValue = SetInputRules.adjustedReps(draft.reps, by: 1) }
            }
        }
    }

    private func adjustmentButton(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 24, weight: .bold)).frame(minWidth: 56, minHeight: 56)
        }.buttonStyle(.bordered).accessibilityLabel("\(label) for \(log.exerciseName)")
    }

    private func inputLayout<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 12))
        return layout { content() }
    }
}

private extension View {
    @ViewBuilder func gymNumberInput(decimal: Bool) -> some View {
        #if os(iOS)
        self.keyboardType(decimal ? .decimalPad : .numberPad)
            .multilineTextAlignment(.center).font(.title2.bold()).monospacedDigit()
            .frame(minHeight: 56).textFieldStyle(.roundedBorder)
        #else
        self.multilineTextAlignment(.center).font(.title2.bold()).monospacedDigit()
            .frame(minHeight: 56).textFieldStyle(.roundedBorder)
        #endif
    }
}

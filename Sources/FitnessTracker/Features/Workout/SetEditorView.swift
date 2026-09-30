import SwiftUI
import SwiftData

@MainActor
struct SetEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: SetEntry
    @State private var weight: Double
    @State private var reps: Int
    @State private var partialReps: Int
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    let onChange: () -> Void

    init(entry: SetEntry, onChange: @escaping () -> Void = {}) {
        self.entry = entry
        self.onChange = onChange
        _weight = State(initialValue: entry.weight)
        _reps = State(initialValue: entry.reps)
        _partialReps = State(initialValue: entry.partialReps)
    }

    var body: some View {
        Form {
            Section(entry.log?.exerciseName ?? "Set") {
                TextField("Weight", value: $weight, format: .number).accessibilityLabel("Weight")
                Stepper("Weight: \(weight.formatted()) \(entry.log?.unit.rawValue ?? "")", onIncrement: {
                    weight = SetInputRules.adjustedWeight(weight, by: entry.log?.weightIncrement ?? 2.5)
                }, onDecrement: { weight = SetInputRules.adjustedWeight(weight, by: -(entry.log?.weightIncrement ?? 2.5)) }).frame(minHeight: 48)
                TextField("Reps", value: $reps, format: .number).accessibilityLabel("Repetitions")
                Stepper("Reps: \(reps)", value: $reps, in: 1...999).frame(minHeight: 48)
                Stepper("Partial reps: \(partialReps)", value: $partialReps, in: 0...999).frame(minHeight: 48)
                Text("Only full reps count toward progression and volume.").font(.caption)
                if let notes = entry.log?.loadNotes, !notes.isEmpty { Text(notes).font(.caption) }
            }
            Button("Save changes") {
                do {
                    try SetEditingService.update(entry, weight: weight, reps: reps, partialReps: partialReps, context: context)
                    onChange(); dismiss()
                } catch { errorMessage = error.localizedDescription }
            }.frame(minHeight: 48).disabled(!SetInputRules.isValid(weight: weight, reps: reps))
            Button("Delete set", role: .destructive) { confirmDelete = true }.frame(minHeight: 48)
        }
        .navigationTitle("Edit set")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .confirmationDialog("Delete this set?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete set", role: .destructive) {
                do {
                    try SetEditingService.delete(entry, context: context)
                    onChange(); dismiss()
                } catch { errorMessage = error.localizedDescription }
            }
        }
        .alert("Couldn’t save set", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(errorMessage ?? "") }
    }

}

import SwiftUI

@MainActor
struct ExerciseSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExerciseSettingsViewModel
    let exercise: Exercise

    init(exercise: Exercise) {
        self.exercise = exercise
        _model = State(initialValue: ExerciseSettingsViewModel(exercise: exercise))
    }

    var body: some View {
        Form {
            Section("Rep range") {
                Stepper("Minimum: \(model.minimum)", value: $model.minimum, in: 1...model.maximum).frame(minHeight: 48)
                Stepper("Maximum: \(model.maximum)", value: $model.maximum, in: model.minimum...100).frame(minHeight: 48)
            }
            Section("Weight increment (\(exercise.unit.rawValue))") {
                TextField("Increment", value: $model.increment, format: .number.precision(.fractionLength(0...2)))
                    .frame(minHeight: 48)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
                Stepper("Adjust by 0.25", value: $model.increment, in: 0.05...100, step: 0.25).frame(minHeight: 48)
            }
            Section {
                Text("Reach the top of the rep range on every working set, then increase weight and restart at the minimum reps.")
                if exercise.isAssisted { Text("For this exercise, the increment reduces assistance.") }
                Text("Changes apply when you add this exercise to a workout. Existing workout targets stay unchanged.")
            }.font(.subheadline)
        }
        .navigationTitle("Progression settings")
        .safeAreaInset(edge: .bottom) {
            Button {
                if model.save(in: context) { dismiss() }
            } label: { Text("Save settings").frame(maxWidth: .infinity, minHeight: 52) }
                .buttonStyle(.borderedProminent).disabled(!model.isValid).padding().background(.regularMaterial)
        }
        .alert("Couldn’t save settings", isPresented: Binding(get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }
}

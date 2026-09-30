import SwiftUI
import PhotosUI

@MainActor
struct ExerciseEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: ExerciseEditorViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(profileID: UUID, exercise: Exercise? = nil) {
        _model = State(initialValue: ExerciseEditorViewModel(profileID: profileID, exercise: exercise))
    }

    var body: some View {
        Form {
            Section("Exercise") {
                TextField("Name", text: $model.name).accessibilityLabel("Exercise name")
                TextField("Muscle group", text: $model.muscleGroup).accessibilityLabel("Muscle group")
                TextField("Equipment", text: $model.equipment).accessibilityLabel("Equipment")
                Picker("Weight unit", selection: $model.unit) {
                    ForEach(WeightUnit.allCases) { Text($0.rawValue).tag($0) }
                }
                Toggle("Favorite", isOn: $model.isFavorite)
                TextField("Setup notes: seat, cable height, bench angle", text: $model.setupNotes, axis: .vertical)
                    .accessibilityLabel("Machine setup notes")
                Toggle("Assisted exercise", isOn: $model.isAssisted)
                TextField("Load notes, e.g. plates only", text: $model.loadNotes, axis: .vertical)
                    .accessibilityLabel("How to record weight")
            }
            Section("Illustration") {
                if let photo = model.photoData {
                    ExercisePhotoView(data: photo, exerciseName: model.name)
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(model.photoData == nil ? "Add photo" : "Change photo", systemImage: "photo.on.rectangle")
                        .frame(minHeight: 48)
                }.disabled(model.isLoadingPhoto)
                if model.isLoadingPhoto { ProgressView("Loading photo") }
                if model.photoData != nil {
                    Button(role: .destructive) { selectedPhoto = nil; model.photoData = nil } label: {
                        Text("Remove photo").frame(minHeight: 44)
                    }.disabled(model.isLoadingPhoto)
                }
                Text("Choose a photo of the machine or exercise. It appears in the exercise details and while logging sets.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(model.isEditing ? "Edit exercise" : "Add exercise")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { ProfilePicker() }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                if model.save(in: context) != nil { dismiss() }
            } label: {
                Text("Save exercise").frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).disabled(!model.canSave).padding().background(.regularMaterial)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            model.isLoadingPhoto = true
            defer { model.isLoadingPhoto = false }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    throw ExerciseEditorError.invalidPhoto
                }
                try Task.checkCancellation()
                model.photoData = try ExercisePhoto.prepare(data)
            } catch is CancellationError {
                // Closing the form or cancelling the picker keeps the previously saved image.
            } catch { model.errorMessage = error.localizedDescription }
        }
        .alert("Couldn’t save exercise", isPresented: Binding(get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }
}

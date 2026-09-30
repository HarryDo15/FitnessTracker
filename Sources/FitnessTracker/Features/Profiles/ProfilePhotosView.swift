import SwiftUI
import SwiftData
import PhotosUI

struct ProfilePhotosView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(profiles) { profile in
            NavigationLink {
                ProfileAvatarEditorView(profile: profile)
            } label: {
                HStack(spacing: 16) {
                    ProfileAvatarView(data: profile.avatarData, symbolName: profile.symbolName, size: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading) {
                        Text(profile.name).font(.headline)
                        Text(profile.avatarData == nil ? "Add photo" : "Change or remove photo")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 6)
            }.accessibilityLabel("Edit photo for \(profile.name)")
        }
        .navigationTitle("Profile photos")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

@MainActor
private struct ProfileAvatarEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var model: ProfileAvatarViewModel
    @State private var selectedPhoto: PhotosPickerItem?

    init(profile: Profile) {
        _model = State(initialValue: ProfileAvatarViewModel(profile: profile))
    }

    var body: some View {
        Form {
            Section {
                ProfileAvatarView(data: model.avatarData, symbolName: model.profile.symbolName, size: 160)
                    .frame(maxWidth: .infinity).padding(.vertical)
                    .accessibilityLabel("Avatar preview for \(model.profile.name)")
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(model.avatarData == nil ? "Add photo" : "Change photo", systemImage: "photo")
                        .frame(minHeight: 48)
                }.disabled(model.isLoading)
                if model.isLoading { ProgressView("Loading photo") }
                if model.avatarData != nil {
                    Button(role: .destructive) {
                        selectedPhoto = nil
                        model.avatarData = nil
                    } label: {
                        Label("Remove photo", systemImage: "trash").frame(minHeight: 44)
                    }.disabled(model.isLoading)
                }
            } footer: {
                Text("Choose a photo with your face near the center. The circular preview shows how it will appear in the profile switcher. Tap Save to keep your changes.")
            }
        }
        .navigationTitle("\(model.profile.name)’s photo")
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        .safeAreaInset(edge: .bottom) {
            Button {
                if model.save(in: context) { dismiss() }
            } label: {
                Text("Save photo").frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).disabled(model.isLoading)
                .padding().background(.regularMaterial)
        }
        .task(id: selectedPhoto) {
            guard let selectedPhoto else { return }
            model.isLoading = true
            defer { model.isLoading = false }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    throw ExerciseEditorError.invalidPhoto
                }
                try Task.checkCancellation()
                model.avatarData = try ExercisePhoto.prepare(data)
            } catch is CancellationError {
                // Dismissing without saving leaves the stored avatar unchanged.
            } catch { model.errorMessage = error.localizedDescription }
        }
        .alert("Couldn’t update photo", isPresented: Binding(get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }
}

#Preview { PreviewHost { NavigationStack { ProfilePhotosView() } } }

import SwiftUI
import SwiftData

public struct ProfilePicker: View {
    @Environment(ProfileContext.self) private var selection
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @State private var showingAvatars = false

    public init() {}

    public var body: some View {
        Menu {
            ForEach(profiles) { profile in
                Button {
                    selection.select(profile)
                } label: {
                    Label(profile.name, systemImage: selection.selectedProfileID == profile.id
                          ? "checkmark.circle.fill" : profile.symbolName)
                }
            }
            Divider()
            Button { showingAvatars = true } label: {
                Label("Edit profile photos", systemImage: "person.crop.circle.badge.plus")
            }
        } label: {
            HStack {
                if let profile = profiles.first(where: { $0.id == selection.selectedProfileID }) {
                    ProfileAvatarView(data: profile.avatarData, symbolName: profile.symbolName, size: 30)
                        .accessibilityHidden(true)
                    Text(profile.name)
                } else {
                    Label("Profile", systemImage: "person.crop.circle")
                }
            }.frame(minHeight: 44)
        }
        .accessibilityLabel("Switch profile")
        .accessibilityValue(profiles.first(where: { $0.id == selection.selectedProfileID })?.name ?? "No profile selected")
        .accessibilityHint("Changes whose workout history and exercise library you are viewing.")
        .disabled(profiles.isEmpty)
        .sheet(isPresented: $showingAvatars) { NavigationStack { ProfilePhotosView() } }
    }
}

#Preview {
    PreviewHost { ProfilePicker().padding() }
}

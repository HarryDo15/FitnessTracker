import SwiftUI

@MainActor
struct RewardSettingsView: View {
    let profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var message: String
    @State private var errorMessage: String?

    init(profile: Profile) {
        self.profile = profile
        _message = State(initialValue: profile.rewardMessage)
    }

    var body: some View {
        Form {
            Section("\(profile.name)’s reward message") {
                TextEditor(text: $message).frame(minHeight: 150).accessibilityLabel("Reward message")
                Text("\(message.count)/200 characters").font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("Your message appears on the punch card and the congratulations screen.")
                Text("Changes update your current card and future cards. Already-earned rewards keep their original message.")
            }.font(.subheadline)
        }
        .navigationTitle("Reward settings")
        .safeAreaInset(edge: .bottom) {
            Button {
                do {
                    try GymVisitService(context: context).saveRewardMessage(message, for: profile)
                    dismiss()
                } catch { errorMessage = error.localizedDescription }
            } label: {
                Text("Save reward message").frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).disabled(GymVisitRules.normalizedMessage(message) == nil)
                .padding().background(.regularMaterial)
        }
        .alert("Couldn’t save reward", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }
}

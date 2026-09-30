import SwiftUI
import SwiftData

struct GymRewardsHomeView: View {
    @Environment(\.modelContext) private var context
    var body: some View { GymRewardsFlowView(context: context) }
}

@MainActor
private struct GymRewardsFlowView: View {
    @Query(sort: \Profile.createdAt) private var profiles: [Profile]
    @Query(sort: \PunchCard.startedAt, order: .reverse) private var cards: [PunchCard]
    @Query(sort: \GymVisit.checkedInAt, order: .reverse) private var visits: [GymVisit]
    @State private var model: GymRewardsViewModel
    @State private var presentedCard: PunchCard?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(context: ModelContext) {
        _model = State(initialValue: GymRewardsViewModel(context: context))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                checkInForm
                if let message = model.message {
                    Text(message).font(.subheadline).accessibilityLabel(message)
                }
                ForEach(profiles.filter(\.punchCardEnabled)) { profile in
                    VStack(alignment: .leading, spacing: 12) {
                        let layout = dynamicTypeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout())
                        layout {
                            Text("\(profile.name)’s punch card").font(.title2.bold())
                                .frame(maxWidth: .infinity, alignment: .leading).accessibilityAddTraits(.isHeader)
                            NavigationLink { RewardSettingsView(profile: profile) } label: {
                                Image(systemName: "gearshape").frame(width: 48, height: 48)
                            }.accessibilityLabel("Edit \(profile.name)’s reward message")
                        }
                        if let card = cards.last(where: { $0.profile?.id == profile.id && $0.archivedAt == nil && $0.reward?.redeemedAt == nil }) {
                            PunchCardView(card: card, stampedVisitIDs: model.stampedVisitIDs, stampTrigger: model.stampTrigger)
                            if card.completedAt != nil {
                                Button { model.celebrationCard = card } label: {
                                    Label("Claim your reward", systemImage: "gift.fill").frame(maxWidth: .infinity, minHeight: 52)
                                }.buttonStyle(.borderedProminent)
                            }
                        }
                        let queued = visits.filter { $0.profile?.id == profile.id && $0.eligibleForPunch && $0.punchCard == nil }.count
                        if queued > 0 {
                            Text("\(queued) saved visit\(queued == 1 ? " is" : "s are") waiting for the next card.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                NavigationLink { PunchCardHistoryView() } label: {
                    Label("Past punch cards", systemImage: "clock.arrow.circlepath").frame(minHeight: 52)
                }
                NavigationLink { GymVisitHistoryView() } label: {
                    Label("All gym visits", systemImage: "calendar").frame(minHeight: 52)
                }
            }.padding()
        }
        .navigationTitle("Gym & rewards")
        .task { model.load(profiles: profiles) }
        .onChange(of: model.announcementTrigger) { _, _ in
            if let message = model.message { GymHaptics.announce(message) }
        }
        .task(id: model.stampTrigger) {
            guard model.stampTrigger > 0 else { return }
            for _ in 0..<model.feedbackPunchCount {
                guard !Task.isCancelled else { return }
                GymHaptics.punch()
                do { try await Task.sleep(for: .milliseconds(170)) } catch { return }
            }
        }
        .task(id: model.celebrationCard?.id) {
            guard let card = model.celebrationCard else { presentedCard = nil; return }
            if !reduceMotion && model.feedbackPunchCount > 0 {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            presentedCard = card
        }
        #if os(iOS)
        .fullScreenCover(item: $presentedCard) { card in
            celebration(card)
        }
        #else
        .sheet(item: $presentedCard) { card in
            celebration(card).frame(minWidth: 440, minHeight: 600)
        }
        #endif
        .alert("Couldn’t save", isPresented: Binding(get: { model.errorMessage != nil && presentedCard == nil },
            set: { if !$0 { model.errorMessage = nil } })) {
                Button("OK") { model.errorMessage = nil }
            } message: { Text(model.errorMessage ?? "") }
    }

    private var checkInForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who’s at the gym?").font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Toggle("Both of us", isOn: Binding(
                get: { !profiles.isEmpty && model.selectedProfileIDs == Set(profiles.map(\.id)) },
                set: { model.selectedProfileIDs = $0 ? Set(profiles.map(\.id)) : [] }
            )).frame(minHeight: 48)
                .accessibilityHint("Selects or clears both profiles. You can select just one person below.")
            ForEach(profiles) { profile in
                Toggle(isOn: Binding(get: { model.selectedProfileIDs.contains(profile.id) }, set: {
                    if $0 { model.selectedProfileIDs.insert(profile.id) }
                    else { model.selectedProfileIDs.remove(profile.id) }
                })) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name).font(.headline)
                        if alreadyCheckedIn(profile) { Text("Already checked in for this date").font(.caption).foregroundStyle(.secondary) }
                    }
                }.frame(minHeight: 52)
            }
            DatePicker("Visit date", selection: $model.selectedDate, in: ...Date.now, displayedComponents: .date)
                .frame(minHeight: 48)
            Button { withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.65)) { model.checkIn() } } label: {
                Label("Check in at gym", systemImage: "location.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 56)
            }.buttonStyle(.borderedProminent).disabled(model.selectedProfileIDs.isEmpty)
        }
    }

    private func alreadyCheckedIn(_ profile: Profile) -> Bool {
        let key = GymVisitRules.dayKey(profileID: profile.id, date: model.selectedDate)
        return visits.contains { $0.profile?.id == profile.id &&
            ($0.dayKey ?? GymVisitRules.dayKey(profileID: profile.id, date: $0.checkedInAt)) == key }
    }

    private func celebration(_ card: PunchCard) -> some View {
        RewardCelebrationView(card: card, errorMessage: model.errorMessage,
            claim: { model.claim(card) }, later: { model.celebrationCard = nil; presentedCard = nil })
    }
}

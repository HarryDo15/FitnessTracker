import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class GymRewardsViewModel {
    var selectedProfileIDs: Set<UUID> = []
    var selectedDate: Date = .now
    var message: String?
    var errorMessage: String?
    var celebrationCard: PunchCard?
    private(set) var stampTrigger = 0
    private(set) var announcementTrigger = 0
    private(set) var stampedVisitIDs: Set<UUID> = []
    private(set) var feedbackPunchCount = 0
    private var loaded = false
    private let service: GymVisitService

    init(context: ModelContext) { service = GymVisitService(context: context) }

    func load(profiles: [Profile]) {
        guard !loaded else { return }
        do {
            try service.prepareCards()
            selectedProfileIDs = Set(profiles.map(\.id))
            celebrationCard = try nextEarnedCard()
            loaded = true
        } catch { errorMessage = error.localizedDescription }
    }

    func checkIn() {
        do {
            let result = try service.checkIn(profileIDs: selectedProfileIDs, date: selectedDate)
            var parts: [String] = []
            if !result.addedNames.isEmpty { parts.append("Checked in: \(result.addedNames.sorted().joined(separator: ", ")).") }
            if !result.duplicateNames.isEmpty { parts.append("Already checked in: \(result.duplicateNames.sorted().joined(separator: ", ")).") }
            message = parts.joined(separator: " ")
            announcementTrigger += 1
            recordPunches(result.punchedVisits)
            celebrationCard = try result.earnedCards.first ?? nextEarnedCard()
        } catch { errorMessage = error.localizedDescription }
    }

    func claim(_ card: PunchCard) {
        do {
            let punches = try service.claim(card)
            recordPunches(punches)
            message = "Reward claimed! Your completed card is saved in history."
            announcementTrigger += 1
            celebrationCard = try nextEarnedCard()
        } catch { errorMessage = error.localizedDescription }
    }

    private func recordPunches(_ visits: [GymVisit]) {
        stampedVisitIDs = Set(visits.map(\.id))
        feedbackPunchCount = visits.count
        if !visits.isEmpty { stampTrigger += 1 }
    }

    private func nextEarnedCard() throws -> PunchCard? {
        try service.context.fetch(FetchDescriptor<PunchCard>(sortBy: [SortDescriptor(\PunchCard.startedAt)]))
            .first { $0.profile?.punchCardEnabled == true && $0.completedAt != nil &&
                     $0.archivedAt == nil && $0.reward?.redeemedAt == nil }
    }
}

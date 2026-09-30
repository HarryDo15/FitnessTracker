import Foundation
import SwiftData

struct GymCheckInResult {
    let addedNames: [String]
    let duplicateNames: [String]
    let punchedVisits: [GymVisit]
    let earnedCards: [PunchCard]
}

@MainActor
final class GymVisitService {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    /// One-time personalization, saved with the rest of SeedData's transaction.
    /// Existing visits and any progress beyond the requested amount are preserved.
    func importStartingPunches(profiles: [Profile], target: Int, now: Date = .now) throws {
        for profile in profiles where profile.punchCardEnabled && profile.initialPunchesSeedVersion < 1 {
            let card = try currentCard(for: profile, now: now)
            let goal = min(card.requiredVisits, max(0, target))
            card.carriedOverPunches += max(0, goal - card.progress)
            profile.initialPunchesSeedVersion = 1
        }
    }

    // All mutations are synchronous on the main actor, with one save/rollback per action.
    // A joint check-in inserts only missing people; duplicates never consume a punch.
    func checkIn(profileIDs: Set<UUID>, date: Date, now: Date = .now) throws -> GymCheckInResult {
        guard !profileIDs.isEmpty else { throw GymVisitError.noProfiles }
        guard GymVisitRules.isAllowedDate(date, now: now, calendar: calendar) else { throw GymVisitError.futureDate }
        let profiles = try context.fetch(FetchDescriptor<Profile>()).filter { profileIDs.contains($0.id) }
        guard profiles.count == profileIDs.count else { throw GymVisitError.unavailableProfile }
        var added: [String] = []
        var duplicates: [String] = []
        var punched: [GymVisit] = []
        var earned: [PunchCard] = []
        do {
            for profile in profiles {
                let key = GymVisitRules.dayKey(profileID: profile.id, date: date, calendar: calendar)
                let existing = try visits(for: profile)
                if existing.contains(where: {
                    ($0.dayKey ?? GymVisitRules.dayKey(profileID: profile.id, date: $0.checkedInAt, calendar: calendar)) == key
                }) {
                    duplicates.append(profile.name)
                    continue
                }
                // Preserve the selected date and an explicit immutable day key.
                let visit = try GymVisit(profile: profile, checkedInAt: date, calendar: calendar)
                context.insert(visit)
                added.append(profile.name)
                if profile.punchCardEnabled {
                    let card = try currentCard(for: profile, now: now)
                    let pending = (existing + [visit]).filter { $0.eligibleForPunch && $0.punchCard == nil }
                    punched += try fill(card, from: pending, now: now)
                    if card.completedAt != nil && card.archivedAt == nil { earned.append(card) }
                }
            }
            try context.save()
            return GymCheckInResult(addedNames: added, duplicateNames: duplicates,
                                    punchedVisits: punched, earnedCards: earned)
        } catch { context.rollback(); throw error }
    }

    /// Returns one open card, including a full card awaiting claim. Does not save itself.
    private func currentCard(for profile: Profile, now: Date) throws -> PunchCard {
        if let card = profile.punchCards.filter({ $0.archivedAt == nil && $0.reward?.redeemedAt == nil })
            .sorted(by: { $0.startedAt < $1.startedAt }).first { return card }
        return try newCard(for: profile, now: now)
    }

    private func newCard(for profile: Profile, now: Date) throws -> PunchCard {
        let card = try PunchCard(profile: profile, title: "10 gym visits", requiredVisits: GymVisitRules.punchesPerCard, startedAt: now)
        context.insert(card)
        context.insert(try Reward(profile: profile, title: profile.rewardMessage, punchCard: card))
        return card
    }

    /// Only distinct, uncredited visit dates can fill a card; a full card never overflows.
    private func fill(_ card: PunchCard, from visits: [GymVisit], now: Date) throws -> [GymVisit] {
        guard card.archivedAt == nil, let profile = card.profile else { return [] }
        var keys = Set(card.visits.map {
            $0.dayKey ?? GymVisitRules.dayKey(profileID: profile.id, date: $0.checkedInAt, calendar: calendar)
        })
        var punched: [GymVisit] = []
        let candidates = visits.filter { $0.profile?.id == profile.id && $0.punchCard == nil && $0.eligibleForPunch }
            .sorted { $0.checkedInAt < $1.checkedInAt }
        let pendingKeys = candidates.map { $0.dayKey ?? GymVisitRules.dayKey(profileID: profile.id, date: $0.checkedInAt, calendar: calendar) }
        var creditable = Set(card.completedAt == nil
            ? GymVisitRules.creditableDayKeys(existing: keys, pending: pendingKeys, required: card.requiredVisits,
                                             carriedOver: card.carriedOverPunches) : [])
        for visit in candidates {
            let key = visit.dayKey ?? GymVisitRules.dayKey(profileID: profile.id, date: visit.checkedInAt, calendar: calendar)
            guard creditable.remove(key) != nil else { continue }
            keys.insert(key)
            visit.punchCard = card
            visit.punchedAt = now
            punched.append(visit)
        }
        if GymVisitRules.isCardComplete(dayKeys: keys, required: card.requiredVisits, carriedOver: card.carriedOverPunches) {
            card.completedAt = card.completedAt ?? now
            if card.reward == nil { context.insert(try Reward(profile: profile, title: profile.rewardMessage, punchCard: card)) }
            card.reward?.earnedAt = card.reward?.earnedAt ?? card.completedAt
        }
        return punched
    }

    func prepareCards(now: Date = .now) throws {
        do {
            let profiles = try context.fetch(FetchDescriptor<Profile>()).filter(\.punchCardEnabled)
            for profile in profiles {
                // Adopt previously redeemed cards into the archive without changing their reward text.
                for card in profile.punchCards where card.archivedAt == nil && card.reward?.redeemedAt != nil {
                    card.archivedAt = card.reward?.redeemedAt
                }
                let card = try currentCard(for: profile, now: now)
                _ = try fill(card, from: visits(for: profile).filter { $0.eligibleForPunch && $0.punchCard == nil }, now: now)
            }
            if context.hasChanges { try context.save() }
        } catch { context.rollback(); throw error }
    }

    /// Idempotent: a second claim cannot archive another card or grant another reward.
    func claim(_ card: PunchCard, now: Date = .now) throws -> [GymVisit] {
        guard card.archivedAt == nil, card.reward?.redeemedAt == nil else { return [] }
        guard let profile = card.profile, card.requiredVisits > 0, card.completedAt != nil, card.progress >= card.requiredVisits,
              let reward = card.reward, reward.earnedAt != nil else { throw GymVisitError.cardNotEarned }
        do {
            reward.redeemedAt = now
            card.archivedAt = now
            let next = try newCard(for: profile, now: now)
            let pending = try visits(for: profile).filter { $0.eligibleForPunch && $0.punchCard == nil }
            let punched = try fill(next, from: pending, now: now)
            try context.save()
            return punched
        } catch { context.rollback(); throw error }
    }

    func saveRewardMessage(_ text: String, for profile: Profile) throws {
        guard let message = GymVisitRules.normalizedMessage(text) else { throw GymVisitError.invalidMessage }
        do {
            profile.rewardMessage = message
            for card in profile.punchCards where card.completedAt == nil && card.archivedAt == nil {
                card.reward?.title = message
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    private func visits(for profile: Profile) throws -> [GymVisit] {
        let id = profile.id
        return try context.fetch(FetchDescriptor<GymVisit>(predicate: #Predicate { $0.profile?.id == id }))
    }
}

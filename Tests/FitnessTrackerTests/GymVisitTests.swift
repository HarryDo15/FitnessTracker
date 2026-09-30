import XCTest
import SwiftData
@testable import FitnessTracker

final class GymVisitTests: XCTestCase {
    @MainActor func testExistingCompletedCardRepairsMissingRewardWithoutRepunching() throws {
        let (container, service, _, girlfriend) = try setup()
        for day in -10 ... -1 { _ = try service.checkIn(profileIDs: [girlfriend.id], date: date(day)) }
        let card = try XCTUnwrap(girlfriend.punchCards.first)
        let earnedAt = try XCTUnwrap(card.completedAt)
        if let reward = card.reward { container.mainContext.delete(reward) }
        card.reward = nil
        try container.mainContext.save()
        try service.prepareCards()
        XCTAssertEqual(card.progress, 10)
        XCTAssertEqual(card.reward?.earnedAt, earnedAt)
        XCTAssertEqual(card.completedAt, earnedAt)
        XCTAssertNoThrow(try service.claim(card))
    }

    @MainActor private func setup() throws -> (ModelContainer, GymVisitService, Profile, Profile) {
        let container = try ModelContainerFactory.make(inMemory: true)
        try SeedData.install(in: container.mainContext, includePersonalValues: false)
        let profiles = try container.mainContext.fetch(FetchDescriptor<Profile>())
        let girlfriend = try XCTUnwrap(profiles.first(where: \.punchCardEnabled))
        let me = try XCTUnwrap(profiles.first(where: { !$0.punchCardEnabled }))
        let service = GymVisitService(context: container.mainContext)
        try service.prepareCards()
        return (container, service, me, girlfriend)
    }

    private func date(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: .now)!
    }

    @MainActor func testSharedCheckInFillsOnlyMissingPersonAndNeverDoublePunches() throws {
        let (container, service, me, girlfriend) = try setup()
        let first = try service.checkIn(profileIDs: [me.id], date: date(-1))
        XCTAssertEqual(first.addedNames, [me.name])
        XCTAssertTrue(first.punchedVisits.isEmpty)
        let shared = try service.checkIn(profileIDs: [me.id, girlfriend.id], date: date(-1))
        XCTAssertEqual(shared.addedNames, [girlfriend.name])
        XCTAssertEqual(shared.duplicateNames, [me.name])
        XCTAssertEqual(shared.punchedVisits.count, 1)
        let duplicate = try service.checkIn(profileIDs: [me.id, girlfriend.id], date: date(-1))
        XCTAssertTrue(duplicate.addedNames.isEmpty)
        XCTAssertTrue(duplicate.punchedVisits.isEmpty)
        XCTAssertEqual(duplicate.duplicateNames.count, 2)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<GymVisit>()), 2)
        XCTAssertEqual(girlfriend.punchCards.first?.progress, 1)
        XCTAssertTrue(me.punchCards.isEmpty)
    }

    @MainActor func testTenthPunchClaimAndQueueRollover() throws {
        let (container, service, _, girlfriend) = try setup()
        for day in -12 ... -3 {
            let result = try service.checkIn(profileIDs: [girlfriend.id], date: date(day))
            XCTAssertEqual(result.punchedVisits.count, 1)
            XCTAssertEqual(result.earnedCards.count, day == -3 ? 1 : 0)
        }
        let original = try XCTUnwrap(girlfriend.punchCards.first)
        XCTAssertEqual(original.progress, 10)
        XCTAssertNotNil(original.completedAt)
        XCTAssertEqual(original.reward?.title, "You earned a treat!")
        XCTAssertNotNil(original.reward?.earnedAt)
        let overflow = try service.checkIn(profileIDs: [girlfriend.id], date: date(-2))
        XCTAssertEqual(overflow.addedNames.count, 1)
        XCTAssertTrue(overflow.punchedVisits.isEmpty)
        XCTAssertEqual(original.progress, 10)
        let credited = try service.claim(original)
        XCTAssertEqual(credited.count, 1)
        XCTAssertNotNil(original.archivedAt)
        XCTAssertNotNil(original.reward?.redeemedAt)
        let next = try XCTUnwrap(girlfriend.punchCards.first { $0.archivedAt == nil })
        XCTAssertNotEqual(next.id, original.id)
        XCTAssertEqual(next.progress, 1)
        XCTAssertEqual(original.progress, 10)
        XCTAssertTrue(try service.claim(original).isEmpty)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PunchCard>()), 2)
        XCTAssertTrue(try service.checkIn(profileIDs: [girlfriend.id], date: date(-2)).addedNames.isEmpty)
        XCTAssertEqual(next.progress, 1, "Claiming cannot bypass the daily visit limit")
    }

    @MainActor func testClaimStartsEmptyCardWhenNothingQueuedAndPersistsHistory() throws {
        let (container, service, _, girlfriend) = try setup()
        for day in -10 ... -1 { _ = try service.checkIn(profileIDs: [girlfriend.id], date: date(day)) }
        let card = try XCTUnwrap(girlfriend.punchCards.first)
        let originalID = card.id
        _ = try service.claim(card)
        let freshContext = ModelContext(container)
        let cards = try freshContext.fetch(FetchDescriptor<PunchCard>())
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.first { $0.archivedAt == nil }?.progress, 0)
        XCTAssertEqual(cards.first { $0.id == originalID }?.progress, 10)
        XCTAssertNotNil(cards.first { $0.id == originalID }?.reward?.redeemedAt)
    }

    @MainActor func testEditableRewardPreservesEarnedAndArchivedMessages() throws {
        let (container, service, _, girlfriend) = try setup()
        defer { withExtendedLifetime(container) {} }
        let card = try XCTUnwrap(girlfriend.punchCards.first)
        try service.saveRewardMessage("  Dinner together!  ", for: girlfriend)
        XCTAssertEqual(card.reward?.title, "Dinner together!")
        for day in -10 ... -1 { _ = try service.checkIn(profileIDs: [girlfriend.id], date: date(day)) }
        try service.saveRewardMessage("Movie night!", for: girlfriend)
        XCTAssertEqual(card.reward?.title, "Dinner together!")
        _ = try service.claim(card)
        XCTAssertEqual(card.reward?.title, "Dinner together!")
        XCTAssertEqual(girlfriend.punchCards.first { $0.archivedAt == nil }?.reward?.title, "Movie night!")
        XCTAssertThrowsError(try service.saveRewardMessage("  ", for: girlfriend))
        XCTAssertThrowsError(try service.saveRewardMessage(String(repeating: "a", count: 201), for: girlfriend))
    }

    @MainActor func testInvalidCheckInsAndPrematureClaimDoNotMutateStore() throws {
        let (container, service, me, girlfriend) = try setup()
        XCTAssertThrowsError(try service.checkIn(profileIDs: [], date: date(0)))
        XCTAssertThrowsError(try service.checkIn(profileIDs: [me.id, girlfriend.id], date: date(1)))
        XCTAssertThrowsError(try service.checkIn(profileIDs: [me.id, UUID()], date: date(0)))
        XCTAssertThrowsError(try service.claim(XCTUnwrap(girlfriend.punchCards.first)))
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<GymVisit>()), 0)
        XCTAssertEqual(girlfriend.punchCards.count, 1)
    }

    @MainActor func testLegacyVisitAndProfileRenameRemainDeduplicated() throws {
        let (container, service, _, girlfriend) = try setup()
        let legacy = try GymVisit(profile: girlfriend, checkedInAt: date(-1))
        legacy.dayKey = nil
        legacy.eligibleForPunch = false
        container.mainContext.insert(legacy)
        girlfriend.name = "Renamed"
        try container.mainContext.save()
        try SeedData.install(in: container.mainContext, includePersonalValues: false)
        XCTAssertTrue(girlfriend.punchCardEnabled)
        XCTAssertTrue(try service.checkIn(profileIDs: [girlfriend.id], date: date(-1)).addedNames.isEmpty)
        XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<GymVisit>()), 1)
    }
}

import XCTest
import SwiftData
@testable import FitnessTracker

final class PersonalizationTests: XCTestCase {
    @MainActor func testHaiBaselineUsesConfirmedLoadsAndFirstAlternativesOnly() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let hai = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { !$0.punchCardEnabled })
        let session = try XCTUnwrap(hai.sessions.first)
        XCTAssertEqual(session.startedAt, BaselineWorkoutSeed.date)
        XCTAssertEqual(session.status, .completed)
        XCTAssertEqual(session.exerciseLogs.count, 21)
        XCTAssertEqual(WorkoutSummary(session: session).setCount, 25)
        let expected: [String: [(Double, Int)]] = [
            "Seated dumbbell curl": [(12, 12)], "Bayesian curl": [(7.5, 12)],
            "Tricep overhead extension": [(17.5, 11)], "Tricep single-arm rope extension": [(5, 13)],
            "Lat pull-down": [(60, 10)], "Machine row": [(50, 10)],
            "Barbell chest-supported row": [(50, 8), (60, 4)], "Cable single-arm pull-down": [(20, 10)],
            "Cable row": [(85, 10)], "Smith machine row": [(30, 6)],
            "Rear delt cable fly": [(2.5, 12)], "Dumbbell shoulder press (50 degrees)": [(26, 9)],
            "Cable lateral raise": [(5, 12), (7.5, 6)], "Smith flat bench press": [(30, 9)],
            "Incline dumbbell press": [(26, 9)], "Smith incline chest press": [(15, 8), (30, 10), (35, 8)],
            "Chest fly (Sulek)": [(12.5, 10)], "Smith machine Bulgarian split squat": [(20, 8)],
            "Smith Romanian deadlift": [(40, 9)], "Smith machine squat": [(60, 5)],
            "Smith calf raise": [(30, 12)]
        ]
        for (name, values) in expected {
            let log = try XCTUnwrap(session.exerciseLogs.first { $0.exerciseName == name }, name)
            XCTAssertEqual(log.orderedSets.map(\.weight), values.map { $0.0 }, name)
            XCTAssertEqual(log.orderedSets.map(\.reps), values.map { $0.1 }, name)
            XCTAssertEqual(log.unit, .kg)
            XCTAssertTrue(log.orderedSets.allSatisfy { $0.completedAt == BaselineWorkoutSeed.date })
        }
        XCTAssertTrue(session.exerciseLogs.first { $0.exerciseName == "Smith machine row" }!.notes.contains("1 partial"))
        XCTAssertTrue(session.exerciseLogs.first { $0.exerciseName == "Tricep overhead extension" }!.notes.contains("uncertain"))
        let squat = try XCTUnwrap(hai.exercises.first { $0.name == "Smith machine squat" })
        let model = WorkoutViewModel(profile: hai, context: context)
        model.start(now: BaselineWorkoutSeed.date.addingTimeInterval(86400))
        model.add(squat)
        let activeLog = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertEqual(model.draft(for: activeLog).weight, 60)
        XCTAssertEqual(model.draft(for: activeLog).reps, 5)
        try SeedData.install(in: context)
        XCTAssertEqual(hai.sessions.filter { $0.isDateOnlyImport }.count, 1)
        XCTAssertEqual(hai.exercises.count, 32)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 0)
        context.delete(session)
        try context.save()
        try SeedData.install(in: context)
        XCTAssertTrue(hai.sessions.allSatisfy { !$0.isDateOnlyImport })
    }

    @MainActor func testBaselineUpgradePreservesExistingHistoryAndDoesNotRecreateDeletedImport() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context, includePersonalValues: false)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let existing = WorkoutSession(profile: qi, startedAt: BaselineWorkoutSeed.date)
        context.insert(existing)
        try context.save()
        try SeedData.install(in: context)
        try SeedData.install(in: context)
        XCTAssertEqual(qi.sessions.count, 2)
        XCTAssertEqual(existing.status, .active)
        let imported = try XCTUnwrap(qi.sessions.first { $0.isDateOnlyImport })
        XCTAssertTrue(imported.exerciseLogs.first { $0.exerciseName == "Hamstring curl" }!.notes.contains("3 partial"))
        context.delete(imported)
        try context.save()
        try SeedData.install(in: context)
        XCTAssertEqual(qi.sessions.count, 1)
        XCTAssertEqual(qi.sessions.first?.id, existing.id)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 0)
    }

    @MainActor func testQiBaselineCreatesHistoryWithoutGymVisits() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let me = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
        XCTAssertEqual(qi.name, "Qi")
        XCTAssertEqual(me.name, "Hai")
        XCTAssertEqual(qi.exercises.count, 16)
        XCTAssertEqual(qi.exercises.filter { $0.startingWeight != nil }.count, 13)
        XCTAssertEqual(me.exercises.count, 32)
        XCTAssertTrue(me.exercises.allSatisfy { $0.startingWeight == nil })
        XCTAssertEqual(qi.sessions.count, 1)
        let baseline = try XCTUnwrap(qi.sessions.first)
        XCTAssertEqual(baseline.startedAt, BaselineWorkoutSeed.date)
        XCTAssertEqual(baseline.status, .completed)
        XCTAssertTrue(baseline.isDateOnlyImport)
        XCTAssertEqual(baseline.exerciseLogs.count, 13)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 0)
        let card = try XCTUnwrap(qi.punchCards.first)
        XCTAssertEqual(card.progress, 7)
        XCTAssertEqual(card.carriedOverPunches, 7)
        XCTAssertNil(card.completedAt)
        let expected: [String: (Double, Int)] = [
            "Hamstring curl": (27.5, 8), "Smith machine squat": (2.5, 10), "Hip thrust": (15, 12),
            "Bulgarian split squat": (5, 10), "Leg extension": (20, 9),
            "Glute machine isolation kick-back": (61, 13), "Shoulder bench press": (6, 10),
            "Tricep extension": (5, 10), "Tricep overhead extension": (2.5, 10),
            "Lateral raise": (2.5, 12), "Lat pull-down": (13, 7), "Cable row": (10, 10),
            "Assisted pull-up": (42.5, 11)
        ]
        for (name, value) in expected {
            let exercise = try XCTUnwrap(qi.exercises.first { $0.name == name })
            XCTAssertEqual(exercise.startingWeight, value.0, name)
            XCTAssertEqual(exercise.startingReps, value.1, name)
            XCTAssertEqual(exercise.startingUnit, .kg)
            let log = try XCTUnwrap(baseline.exerciseLogs.first { $0.exercise?.id == exercise.id })
            XCTAssertEqual(log.sets.count, 1)
            XCTAssertEqual(log.sets.first?.weight, value.0)
            XCTAssertEqual(log.sets.first?.reps, value.1)
            XCTAssertEqual(log.sets.first?.completedAt, BaselineWorkoutSeed.date)
        }
        XCTAssertTrue(qi.exercises.first { $0.name == "Hamstring curl" }!.startingNotes.contains("3 partial"))
        XCTAssertTrue(qi.exercises.first { $0.name == "Leg extension" }!.startingNotes.contains("1 partial"))
    }

    @MainActor func testStartingValuesPrefillAndRealSetsTakePriority() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let exercise = try XCTUnwrap(qi.exercises.first { $0.name == "Bulgarian split squat" })
        let model = WorkoutViewModel(profile: qi, context: context)
        let start = Date.now.addingTimeInterval(-3_600)
        model.start(now: start)
        model.add(exercise)
        let log = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertEqual(model.draft(for: log).weight, 5)
        XCTAssertEqual(model.draft(for: log).reps, 10)
        XCTAssertTrue(log.loadNotes?.contains("per dumbbell") == true)
        XCTAssertEqual(model.previousSets(for: log).count, 1)
        XCTAssertEqual(ExerciseProgress.history(for: exercise).count, 1)
        model.updateDraft(SetDraft(weight: 6, reps: 11), for: log)
        model.logSet(for: log, now: start.addingTimeInterval(60))
        XCTAssertEqual(model.draft(for: log).weight, 6, "Next set follows today’s logged weight")
        model.finish(now: start.addingTimeInterval(120))
        model.start()
        model.add(exercise)
        let nextLog = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertEqual(model.draft(for: nextLog).weight, 6, "Completed history overrides starting weight")
        XCTAssertEqual(model.draft(for: nextLog).reps, 11)
        XCTAssertEqual(ExerciseStartingValues.draft(for: exercise, in: .lb)!.weight, 11.02, accuracy: 0.01)
    }

    @MainActor func testSeedUpgradeIsIdempotentAndPreservesEditsAndExistingVisits() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context, includePersonalValues: false)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        qi.name = "Custom name"
        let hai = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { !$0.punchCardEnabled })
        hai.name = "Me" // Simulate an existing installation before the name migration.
        let originalID = hai.id
        let service = GymVisitService(context: context)
        for offset in [-2, -1] {
            _ = try service.checkIn(profileIDs: [qi.id], date: Calendar.current.date(byAdding: .day, value: offset, to: .now)!)
        }
        try SeedData.install(in: context)
        let card = try XCTUnwrap(qi.punchCards.first)
        XCTAssertEqual(card.progress, 7)
        XCTAssertEqual(card.carriedOverPunches, 5)
        XCTAssertEqual(card.visits.count, 2)
        XCTAssertEqual(qi.name, "Custom name")
        XCTAssertEqual(hai.name, "Hai")
        XCTAssertEqual(hai.id, originalID)
        hai.name = "Custom Hai"
        let lateral = try XCTUnwrap(qi.exercises.first { $0.name == "Lateral raise" })
        lateral.startingWeight = 3
        let hip = try XCTUnwrap(qi.exercises.first { $0.name == "Hip thrust" })
        context.delete(hip)
        try context.save()
        try SeedData.install(in: context)
        XCTAssertEqual(lateral.startingWeight, 3)
        XCTAssertEqual(hai.name, "Custom Hai", "Future launches preserve custom names")
        XCTAssertFalse(qi.exercises.contains { $0.name == "Hip thrust" })
        XCTAssertEqual(card.progress, 7)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 2)
        XCTAssertEqual(qi.sessions.count, 1, "Repeated launches must not duplicate the imported workout")
    }

    @MainActor func testSevenPunchesNeedThreeDistinctVisitsAndNeverReimportAfterClaim() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let service = GymVisitService(context: context)
        let card = try XCTUnwrap(qi.punchCards.first)
        for (index, offset) in [-2, -1, 0].enumerated() {
            let day = Calendar.current.date(byAdding: .day, value: offset, to: .now)!
            _ = try service.checkIn(profileIDs: [qi.id], date: day)
            _ = try service.checkIn(profileIDs: [qi.id], date: day)
            XCTAssertEqual(card.progress, 8 + index)
        }
        XCTAssertNotNil(card.reward?.earnedAt)
        _ = try service.claim(card)
        try SeedData.install(in: context)
        XCTAssertEqual(qi.punchCards.first { $0.archivedAt == nil }?.progress, 0)
        XCTAssertEqual(card.progress, 10)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 3)
    }
}

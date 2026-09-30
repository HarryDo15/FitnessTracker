import XCTest
import SwiftData
@testable import FitnessTracker

final class WorkoutFlowTests: XCTestCase {
    @MainActor func testFirstExercisePrefillAndDiscardEmptyWorkout() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Me")
        context.insert(profile)
        let exercise = Exercise(name: "Squat", muscleGroup: "Legs", equipment: "Barbell", profile: profile)
        context.insert(exercise)
        let model = WorkoutViewModel(profile: profile, context: context)
        model.start()
        model.add(exercise)
        var log = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertTrue(model.previousSets(for: log).isEmpty)
        XCTAssertEqual(model.draft(for: log).weight, 0)
        XCTAssertEqual(model.draft(for: log).reps, 8)
        model.discardEmptyWorkout()
        XCTAssertNil(model.session)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 1)
        model.start()
        model.add(exercise)
        log = try XCTUnwrap(model.session?.exerciseLogs.first)
        model.updateDraft(SetDraft(weight: 30, reps: 8), for: log)
        model.logSet(for: log)
        XCTAssertEqual(model.draft(for: log).weight, 30)
        model.discardEmptyWorkout()
        XCTAssertNotNil(model.session, "Cannot discard a workout with completed sets")
    }

    @MainActor func testStartResumeAndProfileIsolation() throws {
        let container = try PreviewData.makeContainer()
        let context = container.mainContext
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let first = WorkoutViewModel(profile: profiles[0], context: context)
        first.start()
        let id = try XCTUnwrap(first.session?.id)
        first.start()
        XCTAssertEqual(first.session?.id, id)
        let resumed = WorkoutViewModel(profile: profiles[0], context: context)
        resumed.restore()
        XCTAssertEqual(resumed.session?.id, id)
        let second = WorkoutViewModel(profile: profiles[1], context: context)
        second.restore()
        XCTAssertNil(second.session)
        second.start()
        XCTAssertNotEqual(second.session?.id, id)
        first.add(profiles[1].exercises[0])
        XCTAssertNotNil(first.errorMessage)
        XCTAssertTrue(first.session?.exerciseLogs.isEmpty == true)
    }

    @MainActor func testPreviousSetsPrefillLoggingRestAndFinish() throws {
        let container = try PreviewData.makeContainer()
        let context = container.mainContext
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first)
        let previousLog = try XCTUnwrap(profile.sessions.first?.exerciseLogs.first)
        let exercise = try XCTUnwrap(previousLog.exercise)
        let now = Date.now
        let model = WorkoutViewModel(profile: profile, context: context)
        model.start(now: now)
        model.add(exercise)
        model.add(exercise)
        XCTAssertEqual(model.session?.exerciseLogs.count, 1)
        let log = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertEqual(model.previousSets(for: log).count, 3)
        XCTAssertEqual(model.draft(for: log).weight, previousLog.orderedSets[0].weight)
        XCTAssertEqual(model.draft(for: log).reps, 10)
        model.logSet(for: log, now: now)
        XCTAssertEqual(log.sets.count, 1)
        XCTAssertEqual(log.sets.first?.completedAt, now)
        XCTAssertEqual(model.session?.restEndsAt, now.addingTimeInterval(180))
        XCTAssertEqual(model.draft(for: log).reps, 11)
        model.extendRest(now: now)
        XCTAssertEqual(model.session?.restEndsAt, now.addingTimeInterval(210))
        model.skipRest()
        XCTAssertNil(model.session?.restEndsAt)
        model.finish(now: now.addingTimeInterval(300))
        let finished = try XCTUnwrap(model.finishedSession)
        XCTAssertEqual(finished.status, .completed)
        XCTAssertNil(model.session)
        XCTAssertEqual(WorkoutSummary(session: finished).duration, 300)
        XCTAssertEqual(WorkoutSummary(session: finished).setCount, 1)
        let resumed = WorkoutViewModel(profile: profile, context: context)
        resumed.restore()
        XCTAssertNil(resumed.session)
    }

    @MainActor func testPrefillConvertsUnitsAndExcludesIncompleteAndWarmupSets() throws {
        let container = try PreviewData.makeContainer()
        let context = container.mainContext
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first)
        let previousLog = try XCTUnwrap(profile.sessions.first?.exerciseLogs.first)
        let exercise = try XCTUnwrap(previousLog.exercise)
        previousLog.orderedSets[0].isWarmUp = true
        previousLog.orderedSets[1].completedAt = nil
        exercise.unit = .lb
        try context.save()
        let model = WorkoutViewModel(profile: profile, context: context)
        model.start()
        model.add(exercise)
        let log = try XCTUnwrap(model.session?.exerciseLogs.first)
        XCTAssertEqual(model.previousSets(for: log).count, 1)
        XCTAssertEqual(model.draft(for: log).reps, 12)
        XCTAssertEqual(model.draft(for: log).weight,
                       previousLog.orderedSets[2].weight * 2.2046226218, accuracy: 0.01)
    }

    @MainActor func testSummaryMixedUnitsAndAssistance() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Test")
        context.insert(profile)
        let session = WorkoutSession(profile: profile)
        context.insert(session)
        for (index, unit) in [WeightUnit.kg, .lb, .kg].enumerated() {
            let exercise = Exercise(name: "Exercise \(index)", muscleGroup: "Back", equipment: "Machine",
                                    unit: unit, isAssisted: index == 2, profile: profile)
            context.insert(exercise)
            let log = try ExerciseLog(session: session, exercise: exercise, order: index)
            context.insert(log)
            context.insert(try SetEntry(log: log, order: 0, weight: 20, reps: 10, completedAt: .now))
            context.insert(try SetEntry(log: log, order: 1, weight: 100, reps: 10))
        }
        try context.save()
        let summary = WorkoutSummary(session: session)
        XCTAssertEqual(summary.setCount, 3)
        XCTAssertEqual(summary.exerciseCount, 3)
        XCTAssertEqual(summary.volumeByUnit[.kg], 200)
        XCTAssertEqual(summary.volumeByUnit[.lb], 200)
        XCTAssertTrue(summary.hasAssistedSets)
    }

    func testRestUsesWallClockAndDoesNotGoNegative() {
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertEqual(WorkoutCalculations.remainingSeconds(until: now.addingTimeInterval(89.2), now: now), 90)
        XCTAssertEqual(WorkoutCalculations.remainingSeconds(until: now, now: now.addingTimeInterval(300)), 0)
        XCTAssertEqual(WorkoutCalculations.clock(3_661), "1:01:01")
    }
}

import XCTest
import SwiftData
@testable import FitnessTracker

final class ExerciseProgressTests: XCTestCase {
    @MainActor func testShortenedPreviousWorkoutDoesNotRaiseNextActiveTarget() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Me")
        context.insert(profile)
        let exercise = Exercise(name: "Squat", muscleGroup: "Legs", equipment: "Barbell", profile: profile)
        context.insert(exercise)
        for (index, count) in [3, 1].enumerated() {
            let session = WorkoutSession(profile: profile, startedAt: .now.addingTimeInterval(Double(index - 3) * 86400))
            context.insert(session)
            session.status = .completed
            let log = try ExerciseLog(session: session, exercise: exercise, order: 0)
            context.insert(log)
            for order in 0..<count { context.insert(try SetEntry(log: log, order: order, weight: 60, reps: 12, completedAt: .now)) }
        }
        let active = WorkoutSession(profile: profile)
        context.insert(active)
        let log = try ExerciseLog(session: active, exercise: exercise, order: 0)
        context.insert(log)
        try context.save()
        XCTAssertEqual(ExerciseProgress.targets(for: log).first?.weight, 60)
    }

    @MainActor func testSettingsSnapshotAndFiltering() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context, includePersonalValues: false)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let exercise = try XCTUnwrap(profiles[0].exercises.first)
        let settings = ExerciseSettingsViewModel(exercise: exercise)
        settings.minimum = 6
        settings.maximum = 10
        settings.increment = 5
        XCTAssertTrue(settings.save(in: context))
        let session = WorkoutSession(profile: profiles[0], startedAt: .now.addingTimeInterval(-86400))
        context.insert(session)
        let log = try ExerciseLog(session: session, exercise: exercise, order: 0)
        context.insert(log)
        XCTAssertEqual(log.targetRepMinimum, 6)
        XCTAssertEqual(log.targetRepMaximum, 10)
        XCTAssertEqual(log.weightIncrement, 5)
        context.insert(try SetEntry(log: log, order: 0, weight: 60, reps: 10, completedAt: .now))
        context.insert(try SetEntry(log: log, order: 1, weight: 100, reps: 20, completedAt: .now, isWarmUp: true))
        context.insert(try SetEntry(log: log, order: 2, weight: 100, reps: 20))
        try context.save()
        XCTAssertTrue(ExerciseProgress.history(for: exercise).isEmpty, "Active sessions excluded")
        session.status = .completed
        try context.save()
        let history = ExerciseProgress.history(for: exercise)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.sets.count, 1, "Warm-up and planned sets excluded")
        XCTAssertEqual(history.first?.plannedSetCount, 2)
        XCTAssertTrue(ExerciseProgress.history(for: profiles[1].exercises[0]).isEmpty)
        settings.minimum = 8
        settings.maximum = 12
        settings.increment = 2.5
        XCTAssertTrue(settings.save(in: context))
        XCTAssertEqual(log.targetRepMinimum, 6, "Existing targets remain stable")
        XCTAssertEqual(log.weightIncrement, 5)
    }

    @MainActor func testHistoryConvertsUnitsAndGroupsSessionLogs() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Me")
        context.insert(profile)
        let exercise = Exercise(name: "Bench press", muscleGroup: "Chest", equipment: "Barbell", profile: profile)
        context.insert(exercise)
        let session = WorkoutSession(profile: profile)
        context.insert(session)
        session.status = .completed
        for index in 0..<2 {
            let log = try ExerciseLog(session: session, exercise: exercise, order: index)
            context.insert(log)
            context.insert(try SetEntry(log: log, order: 0, weight: 20, reps: 10, completedAt: .now))
        }
        exercise.unit = .lb
        try context.save()
        let history = ExerciseProgress.history(for: exercise)
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history[0].sets.count, 2)
        XCTAssertEqual(try XCTUnwrap(history[0].volume), 400 * 2.2046226218, accuracy: 0.0001)
    }
}

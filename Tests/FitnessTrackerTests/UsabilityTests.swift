import XCTest
import SwiftData
@testable import FitnessTracker

final class UsabilityTests: XCTestCase {
    @MainActor func testRepeatPlansTargetsAndUndoDoesNotCountAsCompleted() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let hai = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { !$0.punchCardEnabled })
        let model = WorkoutViewModel(profile: hai, context: context)
        model.repeatLastWorkout()
        let session = try XCTUnwrap(model.session)
        XCTAssertEqual(session.exerciseLogs.count, 21)
        XCTAssertEqual(WorkoutSummary(session: session).setCount, 0)
        let curl = try XCTUnwrap(session.exerciseLogs.first { $0.exerciseName == "Seated dumbbell curl" })
        XCTAssertEqual(model.draft(for: curl).weight, 14.5, "Top of rep range increases load")
        XCTAssertEqual(model.draft(for: curl).reps, 8)
        XCTAssertEqual(curl.sets.count, 1)
        model.logSet(for: curl)
        XCTAssertEqual(curl.sets.count, 1, "Logging consumes a planned set")
        XCTAssertEqual(WorkoutSummary(session: session).setCount, 1)
        XCTAssertTrue(model.canUndoLastSet)
        model.undoLastSet()
        XCTAssertEqual(WorkoutSummary(session: session).setCount, 0)
        XCTAssertNil(session.restEndsAt)
        XCTAssertFalse(model.canUndoLastSet)
        model.logSet(for: curl)
        XCTAssertEqual(curl.sets.count, 1)
        try SetEditingService.delete(curl.sets[0], context: context)
        XCTAssertNil(session.restEndsAt)
        XCTAssertEqual(WorkoutSummary(session: session).setCount, 0)
        model.repeatLastWorkout()
        XCTAssertEqual(model.session?.id, session.id, "Never replace an unfinished workout")
    }

    @MainActor func testTemplatesPreserveOrderExcludeUnavailableExercisesAndRespectOwnership() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let hai = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let exercises = Array(hai.exercises.prefix(3))
        exercises[1].isArchived = true
        let template = WorkoutTemplate(profile: hai, name: "Leg", exerciseIDs: exercises.map(\.id) + [UUID()], setsPerExercise: 3)
        context.insert(template)
        try context.save()
        let wrong = WorkoutViewModel(profile: qi, context: context)
        wrong.start(template: template)
        XCTAssertNil(wrong.session)
        let model = WorkoutViewModel(profile: hai, context: context)
        model.start(template: template)
        let session = try XCTUnwrap(model.session)
        XCTAssertEqual(session.orderedLogs.compactMap { $0.exercise?.id }, [exercises[0].id, exercises[2].id])
        XCTAssertTrue(session.exerciseLogs.allSatisfy { $0.sets.count == 3 && $0.sets.allSatisfy { $0.completedAt == nil } })
    }

    @MainActor func testEditingHistoryRecomputesVolumeAndRejectsInvalidInputs() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let session = try XCTUnwrap(profile.sessions.first)
        let log = try XCTUnwrap(session.exerciseLogs.first { $0.exerciseName == "Hip thrust" })
        let set = try XCTUnwrap(log.sets.first)
        let originalVolume = try XCTUnwrap(WorkoutSummary(session: session).volumeByUnit[.kg])
        let id = set.id
        let date = set.completedAt
        try SetEditingService.update(set, weight: 20, reps: 10, context: context)
        XCTAssertEqual(set.id, id)
        XCTAssertEqual(set.completedAt, date)
        XCTAssertEqual(WorkoutSummary(session: session).volumeByUnit[.kg]!, originalVolume + 20, accuracy: 0.001)
        XCTAssertThrowsError(try SetEditingService.update(set, weight: -1, reps: 10, context: context))
        XCTAssertEqual(set.weight, 20)
        XCTAssertEqual(ExerciseProgress.history(for: log.exercise!).last?.sets.first?.weight, 20)
    }

    @MainActor func testFavoriteAndSetupNotesPersistPerProfile() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first)
        let exercise = try XCTUnwrap(profile.exercises.first)
        let editor = ExerciseEditorViewModel(profileID: profile.id, exercise: exercise)
        editor.isFavorite = true
        editor.setupNotes = "  Seat 3, cable above 25  "
        XCTAssertNotNil(editor.save(in: context))
        let fresh = ModelContext(container)
        let id = exercise.id
        let saved = try XCTUnwrap(fresh.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == id })).first)
        XCTAssertTrue(saved.isFavorite)
        XCTAssertEqual(saved.setupNotes, "Seat 3, cable above 25")
    }
}

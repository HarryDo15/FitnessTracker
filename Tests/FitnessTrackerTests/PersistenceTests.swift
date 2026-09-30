import XCTest
import SwiftData
@testable import FitnessTracker

final class PersistenceTests: XCTestCase {
    @MainActor func testSeedIsIdempotentAndLibrariesAreIndependent() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context, includePersonalValues: false)
        try SeedData.install(in: context, includePersonalValues: false)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.map { $0.exercises.count }, [15, 15])
        XCTAssertTrue(Set(profiles[0].exercises.map(\.id)).isDisjoint(with: profiles[1].exercises.map(\.id)))
        profiles[0].exercises[0].name = "My custom name"
        context.delete(profiles[0].exercises[1])
        try context.save()
        try SeedData.install(in: context, includePersonalValues: false)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 29)
        XCTAssertFalse(profiles[1].exercises.contains { $0.name == "My custom name" })
    }

    @MainActor func testOwnershipAndSetValidation() throws {
        let container = try PreviewData.makeContainer()
        let profiles = try container.mainContext.fetch(FetchDescriptor<Profile>())
        let session = try XCTUnwrap(profiles[0].sessions.first)
        XCTAssertThrowsError(try ExerciseLog(session: session, exercise: profiles[1].exercises[0], order: 0))
        let log = try XCTUnwrap(session.exerciseLogs.first)
        XCTAssertThrowsError(try SetEntry(log: log, order: 0, weight: -1, reps: 10))
        XCTAssertThrowsError(try SetEntry(log: log, order: 0, weight: 10, reps: 10, rpe: 11))
        XCTAssertThrowsError(try SetEntry(log: log, order: 0, weight: 10, reps: 0, completedAt: .now))
        XCTAssertNoThrow(try SetEntry(log: log, order: 0, weight: 0, reps: 10, rpe: nil))
    }

    @MainActor func testRoundTripSnapshotsAndCascade() throws {
        let container = try PreviewData.makeContainer()
        let context = container.mainContext
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let session = try XCTUnwrap(profiles[0].sessions.first)
        let id = session.id
        let ownerID = profiles[0].id
        let log = try XCTUnwrap(session.exerciseLogs.first)
        let originalName = log.exerciseName
        let exercise = try XCTUnwrap(log.exercise)
        exercise.name = "Renamed"
        exercise.unit = .lb
        try context.save()

        let fresh = ModelContext(container)
        let savedSession = try XCTUnwrap(fresh.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.id == id })).first)
        XCTAssertEqual(savedSession.profile?.id, ownerID)
        XCTAssertEqual(savedSession.exerciseLogs.count, 3)
        let savedLog = try XCTUnwrap(savedSession.exerciseLogs.first { $0.id == log.id })
        XCTAssertEqual(savedLog.exerciseName, originalName)
        XCTAssertEqual(savedLog.unit, .kg)
        XCTAssertTrue(savedSession.exerciseLogs.allSatisfy { $0.sets.count == 3 && $0.sets.allSatisfy { $0.completedAt != nil } })

        context.delete(session)
        try context.save()
        let verifier = ModelContext(container)
        XCTAssertEqual(try verifier.fetchCount(FetchDescriptor<WorkoutSession>()), 1)
        XCTAssertEqual(try verifier.fetchCount(FetchDescriptor<ExerciseLog>()), 3)
        XCTAssertEqual(try verifier.fetchCount(FetchDescriptor<SetEntry>()), 9)
        XCTAssertEqual(try verifier.fetchCount(FetchDescriptor<Exercise>()), 30)
        XCTAssertEqual(try verifier.fetchCount(FetchDescriptor<GymVisit>()), 2)
    }

    @MainActor func testProfileSelectionAndScopedHistory() throws {
        let container = try PreviewData.makeContainer()
        let profiles = try container.mainContext.fetch(FetchDescriptor<Profile>())
        let selection = ProfileContext(defaults: nil)
        for profile in profiles {
            selection.select(profile)
            let id = try XCTUnwrap(selection.selectedProfileID)
            let sessions = try container.mainContext.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.profile?.id == id }))
            XCTAssertEqual(sessions.count, 1)
            XCTAssertEqual(sessions.first?.profile?.id, profile.id)
        }
    }
}

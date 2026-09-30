import XCTest
import SwiftData
@testable import FitnessTracker

final class BackupTests: XCTestCase {
    @MainActor func testVersionOneBackupsStillLoadAndInvalidPartialsAreRejected() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let data = try BackupService.export(context: context)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy["version"] = 1
        for (collection, key) in [("profiles", "partialRepSeedVersion"), ("sets", "partialReps"), ("logs", "muscleGroup")] {
            let records = try XCTUnwrap(legacy[collection] as? [[String: Any]])
            legacy[collection] = records.map { record in var copy = record; copy.removeValue(forKey: key); return copy }
        }
        let oldData = try JSONSerialization.data(withJSONObject: legacy)
        XCTAssertNoThrow(try BackupService.decode(oldData))
        try BackupService.restore(oldData, context: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<SetEntry>()).allSatisfy { $0.partialReps == 0 })
        try SeedData.install(in: context)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        XCTAssertEqual(qi.exercises.first { $0.name == "Hamstring curl" }?.logs.first?.sets.first?.partialReps, 3)
        var invalid = try JSONDecoder().decode(FitnessBackup.self, from: data)
        invalid.sets[0].partialReps = -1
        XCTAssertThrowsError(try BackupService.restore(JSONEncoder().encode(invalid), context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 2)
    }

    @MainActor func testFullBackupRoundTripIncludesImagesTemplatesRewardsAndSnapshots() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let exercise = try XCTUnwrap(qi.exercises.first)
        exercise.isFavorite = true
        exercise.setupNotes = "Seat 3"
        exercise.photoData = Data([1, 2, 3])
        qi.avatarData = Data([4, 5, 6])
        let template = WorkoutTemplate(profile: qi, name: "Leg", exerciseIDs: [exercise.id])
        context.insert(template)
        let service = GymVisitService(context: context)
        for offset in [-3, -2, -1] {
            _ = try service.checkIn(profileIDs: [qi.id], date: Calendar.current.date(byAdding: .day, value: offset, to: .now)!)
        }
        let card = try XCTUnwrap(qi.punchCards.first)
        _ = try service.claim(card)
        // A deleted exercise's snapshot remains restorable without recreating its library entry.
        let removed = try XCTUnwrap(qi.exercises.first { $0.id != exercise.id && !$0.logs.isEmpty })
        context.delete(removed)
        try context.save()
        let data = try BackupService.export(context: context)
        let original = try JSONDecoder().decode(FitnessBackup.self, from: data)
        XCTAssertNoThrow(try BackupService.decode(data))
        exercise.setupNotes = "Changed after backup"
        try context.save()
        try BackupService.restore(data, context: context)
        let restored = try FitnessBackup(context: context)
        XCTAssertEqual(restored.profiles.count, original.profiles.count)
        XCTAssertEqual(restored.exercises.count, original.exercises.count)
        XCTAssertEqual(restored.sessions.count, original.sessions.count)
        XCTAssertEqual(restored.sets.count, original.sets.count)
        XCTAssertEqual(restored.cards.count, 2)
        XCTAssertEqual(restored.visits.count, 3)
        XCTAssertEqual(restored.templates.count, 1)
        XCTAssertEqual(restored.exercises.first { $0.id == exercise.id }?.setupNotes, "Seat 3")
        XCTAssertEqual(restored.exercises.first { $0.id == exercise.id }?.photoData, Data([1, 2, 3]))
        XCTAssertEqual(restored.profiles.first { $0.id == qi.id }?.avatarData, Data([4, 5, 6]))
        XCTAssertEqual(Set(restored.sets.map(\.id)), Set(original.sets.map(\.id)))
        XCTAssertEqual(restored.rewards.filter { $0.redeemedAt != nil }.count, 1)
        try SeedData.install(in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), original.sessions.count)
    }

    @MainActor func testInvalidBackupCannotChangeLiveDataAndCSVQuotesNotes() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let before = try BackupService.export(context: context)
        var archive = try JSONDecoder().decode(FitnessBackup.self, from: before)
        archive.sets[0].weight = -10
        XCTAssertThrowsError(try BackupService.restore(JSONEncoder().encode(archive), context: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 2)
        archive = try JSONDecoder().decode(FitnessBackup.self, from: before)
        archive.exercises[0].profileID = UUID()
        XCTAssertThrowsError(try BackupService.restore(JSONEncoder().encode(archive), context: context))
        archive = try JSONDecoder().decode(FitnessBackup.self, from: before)
        archive.version = 999
        XCTAssertThrowsError(try BackupService.restore(JSONEncoder().encode(archive), context: context))
        let log = try XCTUnwrap(context.fetch(FetchDescriptor<ExerciseLog>()).first)
        log.notes = "=formula, \"quoted\"\nnew line"
        let csv = String(decoding: try BackupService.csv(context: context), as: UTF8.self)
        XCTAssertTrue(csv.contains("\"'=formula, \"\"quoted\"\"\nnew line\""))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Profile>()), 2)
    }
}

import XCTest
import SwiftData
@testable import FitnessTracker

final class GymCompanionTests: XCTestCase {
    @MainActor func testTogetherAlternativeDoesNotOverwritePartnersExerciseAndEmptyFinishIsSafe() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let together = TogetherWorkoutViewModel(profiles: profiles, context: context)
        together.start()
        let hai = try XCTUnwrap(together.models.first { !$0.profile.punchCardEnabled })
        let qi = try XCTUnwrap(together.models.first { $0.profile.punchCardEnabled })
        let smith = try XCTUnwrap(hai.profile.exercises.first { $0.name == "Smith flat bench press" })
        together.choose(smith, for: hai, matchPartner: true)
        XCTAssertNil(together.selectedLogIDs[qi.profile.id], "Never invent a matching exercise in the other library")
        let original = together.selectedLogIDs[hai.profile.id]
        together.choose(qi.profile.exercises[0], for: qi, matchPartner: false)
        XCTAssertEqual(together.selectedLogIDs[hai.profile.id], original)
        together.finish()
        XCTAssertTrue(together.finished)
        XCTAssertTrue(together.models.allSatisfy { $0.session == nil })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 2, "Only the two baselines remain")
        together.start()
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 2)
    }

    @MainActor func testTrainTogetherKeepsWeightsAndUndoSeparateWhileSwitchingTurns() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>()).sorted { $0.name < $1.name }
        let together = TogetherWorkoutViewModel(profiles: profiles, context: context)
        together.start()
        let hai = try XCTUnwrap(together.models.first { !$0.profile.punchCardEnabled })
        let qi = try XCTUnwrap(together.models.first { $0.profile.punchCardEnabled })
        together.selectedProfileID = hai.profile.id
        let exercise = try XCTUnwrap(hai.profile.exercises.first { $0.name == "Smith machine squat" })
        together.choose(exercise, for: hai, matchPartner: true)
        let haiLog = try XCTUnwrap(together.currentLog)
        XCTAssertEqual(hai.draft(for: haiLog).weight, 60)
        hai.logSet(for: haiLog)
        together.nextTurn()
        let qiLog = try XCTUnwrap(together.currentLog)
        XCTAssertEqual(qiLog.exerciseName, haiLog.exerciseName)
        XCTAssertNotEqual(qiLog.exercise?.id, haiLog.exercise?.id)
        XCTAssertEqual(qi.draft(for: qiLog).weight, 2.5)
        qi.logSet(for: qiLog)
        qi.undoLastSet()
        XCTAssertEqual(haiLog.sets.filter { $0.completedAt != nil }.count, 1)
        XCTAssertEqual(qiLog.sets.filter { $0.completedAt != nil }.count, 0)
        qi.logSet(for: qiLog)
        let haiID = hai.session?.id
        let qiID = qi.session?.id
        together.finish()
        XCTAssertTrue(together.finished)
        XCTAssertEqual(hai.finishedSession?.id, haiID)
        XCTAssertEqual(qi.finishedSession?.id, qiID)
        XCTAssertEqual(hai.finishedSession?.profile?.id, hai.profile.id)
        XCTAssertEqual(qi.finishedSession?.profile?.id, qi.profile.id)
    }

    @MainActor func testSubstitutionPreservesCompletedSourceSetsAndUsesAlternativeHistory() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let hai = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let model = WorkoutViewModel(profile: hai, context: context)
        model.repeatLastWorkout()
        let session = try XCTUnwrap(model.session)
        let original = try XCTUnwrap(session.orderedLogs.first)
        model.logSet(for: original)
        let completedID = try XCTUnwrap(original.sets.first { $0.completedAt != nil }?.id)
        let replacement = Exercise(name: "Alternative curl", muscleGroup: "Biceps", equipment: "Cable", profile: hai)
        replacement.startingWeight = 7.5; replacement.startingReps = 9; replacement.startingUnit = .kg
        context.insert(replacement)
        try context.save()
        XCTAssertNil(model.substitute(original, with: qi.exercises[0]))
        let swapped = try XCTUnwrap(model.substitute(original, with: replacement))
        XCTAssertEqual(original.sets.map(\.id), [completedID])
        XCTAssertEqual(swapped.order, original.order + 1)
        XCTAssertEqual(swapped.exercise?.id, replacement.id)
        XCTAssertEqual(model.draft(for: swapped).weight, 7.5)
        XCTAssertEqual(model.draft(for: swapped).reps, 9)
        XCTAssertTrue(swapped.sets.allSatisfy { $0.completedAt == nil })
        let ids = session.orderedLogs.map(\.id).reversed()
        XCTAssertTrue(model.reorder(Array(ids)))
        XCTAssertEqual(session.orderedLogs.map(\.id), Array(ids))
        XCTAssertFalse(model.reorder([UUID()]))
        XCTAssertEqual(original.sets[0].id, completedID)
    }

    @MainActor func testPartialRepsPersistButCannotInflateProgressOrRecords() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let exercise = try XCTUnwrap(qi.exercises.first { $0.name == "Hamstring curl" })
        let baseline = try XCTUnwrap(exercise.logs.first)
        XCTAssertEqual(baseline.sets[0].partialReps, 3)
        let model = WorkoutViewModel(profile: qi, context: context)
        model.start()
        model.add(exercise)
        let log = try XCTUnwrap(model.session?.exerciseLogs.first)
        model.updateDraft(SetDraft(weight: 27.5, reps: 8, partialReps: 9), for: log)
        model.logSet(for: log)
        let set = try XCTUnwrap(log.sets.first)
        XCTAssertEqual(set.partialReps, 9)
        XCTAssertNil(model.recordMessage)
        XCTAssertEqual(WorkoutSummary(session: model.session!).volumeByUnit[.kg], 220)
        XCTAssertEqual(ExerciseProgress.performance(for: log, unit: .kg).totalReps, 8)
        XCTAssertThrowsError(try SetEditingService.update(set, weight: 27.5, reps: 8, partialReps: -1, context: context))
        let data = try BackupService.export(context: context)
        let archive = try BackupService.decode(data)
        XCTAssertEqual(archive.sets.first { $0.id == set.id }?.partialReps, 9)
        try SetEditingService.update(baseline.sets[0], weight: 27.5, reps: 8, partialReps: 0, context: context)
        try SeedData.install(in: context)
        XCTAssertEqual(baseline.sets[0].partialReps, 0, "Migration must not overwrite later corrections")
    }

    @MainActor func testPersonalRecordsCompareSameExerciseAndReverseAssistance() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let qi = try XCTUnwrap(context.fetch(FetchDescriptor<Profile>()).first { $0.punchCardEnabled })
        let model = WorkoutViewModel(profile: qi, context: context)
        model.start()
        let hip = try XCTUnwrap(qi.exercises.first { $0.name == "Hip thrust" })
        model.add(hip)
        let hipLog = try XCTUnwrap(model.session?.exerciseLogs.first)
        model.updateDraft(SetDraft(weight: 17.5, reps: 12), for: hipLog)
        model.logSet(for: hipLog)
        XCTAssertTrue(model.recordMessage?.contains("Heaviest") == true)
        XCTAssertTrue(model.recordMessage?.contains("1RM") == true)
        let assisted = try XCTUnwrap(qi.exercises.first { $0.isAssisted })
        model.add(assisted)
        let assistedLog = try XCTUnwrap(model.session?.exerciseLogs.first { $0.isAssisted })
        model.updateDraft(SetDraft(weight: 40, reps: 11), for: assistedLog)
        model.logSet(for: assistedLog)
        XCTAssertTrue(model.recordMessage?.contains("Lowest assistance") == true)
        XCTAssertFalse(model.recordMessage?.contains("1RM") == true)
    }

    @MainActor func testWeeklyConsistencyCountsDistinctDaysAndPreservesMuscleSnapshots() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let profile = Profile(name: "Test")
        context.insert(profile)
        let exercise = Exercise(name: "Squat", muscleGroup: "Quadriceps / Glutes", equipment: "Smith", profile: profile)
        context.insert(exercise)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21))!
        for hour in [1, 2, 25, 169] {
            let session = WorkoutSession(profile: profile, startedAt: start.addingTimeInterval(Double(hour) * 3600))
            session.status = .completed; session.endedAt = session.startedAt
            context.insert(session)
            let log = try ExerciseLog(session: session, exercise: exercise, order: 0)
            context.insert(log)
            context.insert(try SetEntry(log: log, order: 0, weight: 20, reps: 8, completedAt: session.startedAt))
        }
        exercise.muscleGroup = "Changed later"
        try context.save()
        let week = WeeklyActivity(profile: profile, start: start, calendar: calendar)
        XCTAssertEqual(week.dayCount, 2)
        XCTAssertEqual(week.sessionCount, 3)
        XCTAssertEqual(week.muscles["Glutes"], 3)
        XCTAssertNil(week.muscles["Changed later"])
    }
}

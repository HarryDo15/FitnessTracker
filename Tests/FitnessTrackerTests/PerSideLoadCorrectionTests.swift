import XCTest
import SwiftData
@testable import FitnessTracker

final class PerSideLoadCorrectionTests: XCTestCase {
    @MainActor func testBulgarianCorrectionUpgradesBothOldVersionsWithoutRepeatingConversions() throws {
        for previousVersion in [0, 1] {
            let container = try ModelContainerFactory.make(inMemory: true)
            let context = container.mainContext
            try SeedData.install(in: context)
            let profiles = try context.fetch(FetchDescriptor<Profile>())
            let hai = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
            let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
            let baseline = try XCTUnwrap(hai.sessions.first)
            let log = try XCTUnwrap(baseline.exerciseLogs.first { $0.exerciseName == "Smith machine Bulgarian split squat" })
            let squat = try XCTUnwrap(baseline.exerciseLogs.first { $0.exerciseName == "Smith machine squat" })
            let setID = log.sets[0].id
            hai.perSideLoadCorrectionVersion = previousVersion
            log.sets[0].weight = 50
            log.notes = "50 kg total, including the bar."
            log.loadNotes = "Enter total weight including the bar."
            log.exercise?.loadNotes = log.loadNotes!
            try context.save()
            try SeedData.install(in: context)
            try SeedData.install(in: context)
            XCTAssertEqual(log.sets[0].weight, 20)
            XCTAssertEqual(log.sets[0].reps, 8)
            XCTAssertEqual(log.sets[0].id, setID)
            XCTAssertEqual(log.loadNotes, PerSideLoadCorrection.loadNotes)
            XCTAssertEqual(log.exercise?.loadNotes, PerSideLoadCorrection.loadNotes)
            XCTAssertEqual(squat.sets[0].weight, 60, "Already per-side weights must remain unchanged")
            XCTAssertEqual(hai.sessions.count, 1)
            XCTAssertEqual(qi.punchCards.first?.progress, 7)
            XCTAssertEqual(hai.perSideLoadCorrectionVersion, 2)
            log.sets[0].weight = 22.5
            try context.save()
            try SeedData.install(in: context)
            XCTAssertEqual(log.sets[0].weight, 22.5, "Later edits are preserved")
        }
    }

    @MainActor func testExistingStoreConvertsTotalsOnceAndCorrectsHipThrust() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        try SeedData.install(in: context)
        let profiles = try context.fetch(FetchDescriptor<Profile>())
        let qi = try XCTUnwrap(profiles.first { $0.punchCardEnabled })
        let hai = try XCTUnwrap(profiles.first { !$0.punchCardEnabled })
        let oldLabel = "Enter total plates on both sides. Exclude the bar and machine weight."
        let oldWeights: [String: [Double]] = [
            "Smith machine row": [60], "Smith flat bench press": [60],
            "Smith incline chest press": [30, 60, 70], "Smith Romanian deadlift": [80],
            "Smith machine squat": [120], "Smith calf raise": [60]
        ]
        for profile in profiles { profile.perSideLoadCorrectionVersion = 0 }
        for log in hai.sessions[0].exerciseLogs {
            guard let values = oldWeights[log.exerciseName] else { continue }
            log.loadNotes = oldLabel
            log.exercise?.loadNotes = oldLabel
            for (set, weight) in zip(log.orderedSets, values) { set.weight = weight }
        }
        let hip = try XCTUnwrap(qi.exercises.first { $0.name == "Hip thrust" })
        let squat = try XCTUnwrap(qi.exercises.first { $0.name == "Smith machine squat" })
        hip.loadNotes = oldLabel
        hip.startingNotes = "7.5 kg of plates on each side."
        squat.loadNotes = oldLabel
        squat.startingWeight = 5
        let hipLog = try XCTUnwrap(qi.sessions[0].exerciseLogs.first { $0.exercise?.id == hip.id })
        hipLog.loadNotes = oldLabel
        hipLog.sets[0].weight = 15
        let squatLog = try XCTUnwrap(qi.sessions[0].exerciseLogs.first { $0.exercise?.id == squat.id })
        squatLog.loadNotes = oldLabel
        squatLog.sets[0].weight = 5
        let sessionIDs = Set(profiles.flatMap(\.sessions).map(\.id))
        try context.save()
        try SeedData.install(in: context)
        try SeedData.install(in: context)
        XCTAssertEqual(hip.startingWeight, 15)
        XCTAssertEqual(hipLog.sets[0].weight, 15)
        XCTAssertEqual(squat.startingWeight, 2.5)
        XCTAssertEqual(squatLog.sets[0].weight, 2.5)
        XCTAssertEqual(squatLog.notes, "2.5 kg of plates on each side.")
        for log in hai.sessions[0].exerciseLogs {
            guard let old = oldWeights[log.exerciseName] else { continue }
            XCTAssertEqual(log.orderedSets.map(\.weight), old.map { $0 / 2 }, log.exerciseName)
            XCTAssertEqual(log.loadNotes, PerSideLoadCorrection.loadNotes)
        }
        XCTAssertEqual(Set(profiles.flatMap(\.sessions).map(\.id)), sessionIDs)
        XCTAssertEqual(qi.punchCards.first?.progress, 7)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GymVisit>()), 0)
        let barbell = try XCTUnwrap(hai.sessions[0].exerciseLogs.first { $0.exerciseName == "Barbell chest-supported row" })
        XCTAssertEqual(barbell.orderedSets.map(\.weight), [50, 60], "Non-Smith barbell convention is unchanged")
    }
}

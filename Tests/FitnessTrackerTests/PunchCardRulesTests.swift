import XCTest
@testable import FitnessTracker

final class PunchCardRulesTests: XCTestCase {
    func testSevenCarriedOverPunchesLeaveOnlyThreeNewSlots() {
        let newDays = GymVisitRules.creditableDayKeys(existing: [], pending: ["a", "a", "b", "c", "d"], carriedOver: 7)
        XCTAssertEqual(newDays, ["a", "b", "c"])
        XCTAssertFalse(GymVisitRules.isCardComplete(dayKeys: ["a", "b"], carriedOver: 7))
        XCTAssertTrue(GymVisitRules.isCardComplete(dayKeys: Set(newDays), carriedOver: 7))
    }

    func testTenthDistinctDayCompletesCardAndDuplicatesDoNot() {
        let nine = Set((1...9).map { "day-\($0)" })
        XCTAssertFalse(GymVisitRules.isCardComplete(dayKeys: nine))
        XCTAssertTrue(GymVisitRules.creditableDayKeys(existing: nine, pending: ["day-9"]).isEmpty)
        let credited = GymVisitRules.creditableDayKeys(existing: nine, pending: ["day-9", "day-10", "day-11"])
        XCTAssertEqual(credited, ["day-10"])
        XCTAssertTrue(GymVisitRules.isCardComplete(dayKeys: nine.union(credited)))
        XCTAssertTrue(GymVisitRules.creditableDayKeys(existing: nine.union(credited), pending: ["day-11"]).isEmpty)
    }

    func testFreshCardAndQueuedDates() {
        let queued = ["day-11", "day-11", "day-12"]
        XCTAssertEqual(GymVisitRules.creditableDayKeys(existing: [], pending: queued), ["day-11", "day-12"])
        XCTAssertFalse(GymVisitRules.isCardComplete(dayKeys: []))
        XCTAssertFalse(GymVisitRules.isCardComplete(dayKeys: [], required: 0))
        XCTAssertTrue(GymVisitRules.creditableDayKeys(existing: [], pending: queued, required: 0).isEmpty)
    }
}

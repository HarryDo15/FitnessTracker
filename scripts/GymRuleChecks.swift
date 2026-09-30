import Foundation

enum GymRuleChecks {
    static func run() -> Int {
        var checks = 0
        func expect(_ value: Bool, _ message: String) {
            precondition(value, message)
            checks += 1
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let id = UUID()
        let other = UUID()
        let formatter = ISO8601DateFormatter()
        func date(_ value: String) -> Date { formatter.date(from: value)! }
        let morning = date("2026-09-29T00:01:00+08:00")
        let evening = date("2026-09-29T23:59:00+08:00")
        let tomorrow = date("2026-09-30T00:01:00+08:00")
        let key = GymVisitRules.dayKey(profileID: id, date: morning, calendar: calendar)
        expect(key == GymVisitRules.dayKey(profileID: id, date: evening, calendar: calendar), "Morning/evening same day deduplicate")
        expect(key != GymVisitRules.dayKey(profileID: other, date: morning, calendar: calendar), "Two profiles may visit together")
        expect(key != GymVisitRules.dayKey(profileID: id, date: tomorrow, calendar: calendar), "Local midnight permits another visit")
        expect(key.hasSuffix("2026-09-29"), "Persist a Gregorian date label")
        expect(GymVisitRules.isAllowedDate(evening, now: morning, calendar: calendar), "Check-in is date based, not clock-time based")
        expect(!GymVisitRules.isAllowedDate(tomorrow, now: morning, calendar: calendar), "Reject future dates")
        expect(GymVisitRules.isAllowedDate(morning, now: tomorrow, calendar: calendar), "Allow backdating")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let fallFirst = date("2026-11-01T01:30:00-04:00")
        let fallSecond = date("2026-11-01T01:30:00-05:00")
        expect(GymVisitRules.dayKey(profileID: id, date: fallFirst, calendar: calendar)
               == GymVisitRules.dayKey(profileID: id, date: fallSecond, calendar: calendar), "DST repeated hour stays one visit")
        let springFirst = date("2026-03-08T01:30:00-05:00")
        let springSecond = date("2026-03-08T03:30:00-04:00")
        expect(GymVisitRules.dayKey(profileID: id, date: springFirst, calendar: calendar)
               == GymVisitRules.dayKey(profileID: id, date: springSecond, calendar: calendar), "DST skipped hour stays one visit")
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        expect(GymVisitRules.dayKey(profileID: id, date: fallFirst, calendar: calendar)
               == GymVisitRules.dayKey(profileID: id, date: fallFirst, calendar: buddhist), "Calendar preference does not change stored date keys")
        expect(GymVisitRules.remainingSlots(progress: 0) == 10, "New cards have ten slots")
        expect(GymVisitRules.remainingSlots(progress: 9) == 1, "Ninth visit leaves one slot")
        expect(GymVisitRules.remainingSlots(progress: 10) == 0, "Tenth visit fills card")
        expect(GymVisitRules.remainingSlots(progress: 11) == 0, "A card cannot have negative remaining slots")
        expect(GymVisitRules.normalizedMessage("  You earned a treat!\n") == "You earned a treat!", "Trim saved reward text")
        expect(GymVisitRules.normalizedMessage(" \n ") == nil, "Reject empty reward text")
        expect(GymVisitRules.normalizedMessage(String(repeating: "x", count: 200)) != nil, "Allow 200 characters")
        expect(GymVisitRules.normalizedMessage(String(repeating: "x", count: 201)) == nil, "Reject excessive reward text")
        let nine = Set((1...9).map { "day-\($0)" })
        expect(!GymVisitRules.isCardComplete(dayKeys: nine), "Nine unique visits cannot earn reward")
        expect(GymVisitRules.creditableDayKeys(existing: nine, pending: ["day-9"]).isEmpty, "Duplicate ninth visit cannot earn reward")
        let lastPunch = GymVisitRules.creditableDayKeys(existing: nine, pending: ["day-9", "day-10", "day-11"])
        expect(lastPunch == ["day-10"], "Only one queued visit fits in the last slot")
        expect(GymVisitRules.isCardComplete(dayKeys: nine.union(lastPunch)), "Tenth unique visit earns reward")
        expect(GymVisitRules.creditableDayKeys(existing: nine.union(lastPunch), pending: ["day-11"]).isEmpty, "Full card never overflows")
        expect(GymVisitRules.creditableDayKeys(existing: [], pending: ["day-11", "day-11", "day-12"]) == ["day-11", "day-12"], "Next card deduplicates queued dates")
        expect(!GymVisitRules.isCardComplete(dayKeys: []), "New card is incomplete")
        expect(!GymVisitRules.isCardComplete(dayKeys: [], required: 0), "Invalid goal never earns reward")
        return checks
    }
}

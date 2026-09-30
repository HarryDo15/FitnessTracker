import Foundation

enum GymVisitRules {
    static let punchesPerCard = 10
    static let defaultRewardMessage = "You earned a treat!"

    // Date keys use the chosen date's Gregorian components in the device's local zone.
    // Save the key permanently: changing time zones must not move an existing check-in.
    static func dayKey(profileID: UUID, date: Date, calendar: Calendar = .current) -> String {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        let parts = local.dateComponents([.year, .month, .day], from: date)
        return "\(profileID.uuidString)|\(String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!))"
    }

    static func isAllowedDate(_ date: Date, now: Date, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) <= calendar.startOfDay(for: now)
    }

    static func remainingSlots(progress: Int, required: Int = punchesPerCard) -> Int {
        guard required > 0 else { return 0 }
        return required - min(required, max(0, progress))
    }

    static func isCardComplete(dayKeys: Set<String>, required: Int = punchesPerCard, carriedOver: Int = 0) -> Bool {
        required > 0 && dayKeys.count + min(required, max(0, carriedOver)) >= required
    }

    /// Returns new unique dates in input order, stopping at the card boundary.
    static func creditableDayKeys(existing: Set<String>, pending: [String], required: Int = punchesPerCard,
                                  carriedOver: Int = 0) -> [String] {
        var seen = existing
        var credited: [String] = []
        for key in pending {
            guard remainingSlots(progress: seen.count + min(max(0, required), max(0, carriedOver)), required: required) > 0 else { break }
            if seen.insert(key).inserted { credited.append(key) }
        }
        return credited
    }

    static func normalizedMessage(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !value.isEmpty && value.count <= 200 ? value : nil
    }
}

enum GymVisitError: LocalizedError {
    case noProfiles, futureDate, invalidMessage, cardNotEarned, unavailableProfile

    var errorDescription: String? {
        switch self {
        case .noProfiles: return "Choose at least one person to check in."
        case .futureDate: return "Choose today or a past date."
        case .invalidMessage: return "Enter a reward message between 1 and 200 characters."
        case .cardNotEarned: return "Complete all 10 punches before claiming this reward."
        case .unavailableProfile: return "This profile is no longer available."
        }
    }
}

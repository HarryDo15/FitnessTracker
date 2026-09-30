import Foundation
import SwiftData

@MainActor
enum SetEditingService {
    static func update(_ entry: SetEntry, weight: Double, reps: Int, context: ModelContext) throws {
        guard SetInputRules.isValid(weight: weight, reps: reps, completed: entry.completedAt != nil) else {
            throw ModelValidationError.invalidSet
        }
        entry.weight = weight
        entry.reps = reps
        let session = entry.log?.session
        if session?.status == .active { session?.restEndsAt = nil }
        do {
            try context.save()
            if let session, session.status == .active { RestAlerts.shared.cancel(sessionID: session.id) }
        } catch { context.rollback(); throw error }
    }

    static func delete(_ entry: SetEntry, context: ModelContext) throws {
        let session = entry.log?.session
        if session?.status == .active { session?.restEndsAt = nil }
        context.delete(entry)
        do {
            try context.save()
            if let session, session.status == .active { RestAlerts.shared.cancel(sessionID: session.id) }
        } catch { context.rollback(); throw error }
    }
}

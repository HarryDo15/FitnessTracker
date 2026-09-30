import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        if case let .invalid(reason) = self { return "Backup could not be restored: \(reason)" }
        return nil
    }
}

@MainActor
enum BackupService {
    static func export(context: ModelContext) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(FitnessBackup(context: context))
    }

    static func decode(_ data: Data) throws -> FitnessBackup {
        guard data.count <= 100_000_000 else { throw BackupError.invalid("file exceeds 100 MB.") }
        let archive = try JSONDecoder().decode(FitnessBackup.self, from: data)
        guard (1...2).contains(archive.version) else { throw BackupError.invalid("unsupported backup version.") }
        // Build a separate store first, so malformed records never touch the live database.
        let staging = try ModelContainerFactory.make(inMemory: true)
        try populate(archive, context: staging.mainContext)
        try staging.mainContext.save()
        return archive
    }

    static func restore(_ data: Data, context: ModelContext) throws {
        let archive = try decode(data)
        do {
            // One transaction: failure rolls back deletion and insertion together.
            for item in try context.fetch(FetchDescriptor<SetEntry>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<ExerciseLog>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<GymVisit>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<Reward>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<PunchCard>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<WorkoutTemplate>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<WorkoutSession>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(item) }
            for item in try context.fetch(FetchDescriptor<Profile>()) { context.delete(item) }
            try populate(archive, context: context)
            try context.save()
            RestAlerts.shared.disable()
            RestLiveActivity.shared.endAll()
        } catch { context.rollback(); throw error }
    }

    private static func populate(_ archive: FitnessBackup, context: ModelContext) throws {
        let allIDs = archive.profiles.map(\.id) + archive.exercises.map(\.id) + archive.sessions.map(\.id) +
            archive.logs.map(\.id) + archive.sets.map(\.id) + archive.cards.map(\.id) +
            archive.rewards.map(\.id) + archive.visits.map(\.id) + archive.templates.map(\.id)
        guard !archive.profiles.isEmpty, allIDs.count <= 100_000, Set(allIDs).count == allIDs.count else {
            throw BackupError.invalid("missing profiles, duplicate IDs, or too many records.")
        }
        var profiles: [UUID: Profile] = [:]
        var exercises: [UUID: Exercise] = [:]
        var sessions: [UUID: WorkoutSession] = [:]
        var logs: [UUID: ExerciseLog] = [:]
        var cards: [UUID: PunchCard] = [:]
        for record in archive.profiles {
            let model = Profile(name: record.name)
            record.apply(to: model); context.insert(model); profiles[model.id] = model
        }
        for record in archive.exercises {
            guard let profile = record.profileID.flatMap({ profiles[$0] }), record.weightIncrement.isFinite,
                  record.weightIncrement > 0, record.targetRepMinimum > 0,
                  record.targetRepMaximum >= record.targetRepMinimum else { throw BackupError.invalid("invalid exercise.") }
            let model = Exercise(name: record.name, muscleGroup: record.muscleGroup, equipment: record.equipment, profile: profile)
            record.apply(to: model); context.insert(model); exercises[model.id] = model
        }
        for record in archive.sessions {
            guard let profile = record.profileID.flatMap({ profiles[$0] }),
                  record.endedAt.map({ $0 >= record.startedAt }) ?? true else { throw BackupError.invalid("invalid session.") }
            let model = WorkoutSession(profile: profile)
            record.apply(to: model); context.insert(model); sessions[model.id] = model
        }
        for record in archive.logs {
            guard let session = record.sessionID.flatMap({ sessions[$0] }), let profile = session.profile else {
                throw BackupError.invalid("missing session for an exercise log.")
            }
            let exercise: Exercise
            let placeholder = record.exerciseID == nil
            if placeholder {
                exercise = Exercise(name: record.exerciseName, muscleGroup: "", equipment: "", profile: profile)
            } else {
                guard let linked = record.exerciseID.flatMap({ exercises[$0] }), linked.profile?.id == profile.id else {
                    throw BackupError.invalid("exercise belongs to another profile or is missing.")
                }
                exercise = linked
            }
            let wasArchived = exercise.isArchived
            exercise.isArchived = false
            let model: ExerciseLog
            do { model = try ExerciseLog(session: session, exercise: exercise, order: record.order,
                    targetRepMinimum: record.targetRepMinimum, targetRepMaximum: record.targetRepMaximum) }
            catch { exercise.isArchived = wasArchived; throw error }
            exercise.isArchived = wasArchived
            record.apply(to: model)
            if placeholder {
                model.exercise = nil
                exercise.profile = nil
                context.delete(exercise)
            }
            context.insert(model); logs[model.id] = model
        }
        for record in archive.sets {
            guard let log = record.logID.flatMap({ logs[$0] }) else { throw BackupError.invalid("missing exercise log for a set.") }
            let model = try SetEntry(log: log, order: record.order, weight: record.weight, reps: record.reps,
                                     rpe: record.rpe, completedAt: record.completedAt, isWarmUp: record.isWarmUp, partialReps: record.partialReps ?? 0)
            record.apply(to: model); context.insert(model)
        }
        for record in archive.cards {
            guard let profile = record.profileID.flatMap({ profiles[$0] }), record.carriedOverPunches >= 0,
                  record.carriedOverPunches <= record.requiredVisits else { throw BackupError.invalid("invalid punch card.") }
            let model = try PunchCard(profile: profile, title: record.title, requiredVisits: record.requiredVisits)
            record.apply(to: model); context.insert(model); cards[model.id] = model
        }
        var rewardCardIDs: Set<UUID> = []
        for record in archive.rewards {
            guard let profile = record.profileID.flatMap({ profiles[$0] }) else { throw BackupError.invalid("missing reward profile.") }
            let card = record.punchCardID.flatMap { cards[$0] }
            if let id = record.punchCardID {
                guard card != nil, rewardCardIDs.insert(id).inserted else { throw BackupError.invalid("duplicate or missing reward card.") }
            }
            let model = try Reward(profile: profile, title: record.title, punchCard: card)
            record.apply(to: model); context.insert(model)
        }
        var dayKeys: Set<String> = []
        var visitSessionIDs: Set<UUID> = []
        for record in archive.visits {
            guard let profile = record.profileID.flatMap({ profiles[$0] }) else { throw BackupError.invalid("missing visit profile.") }
            if let key = record.dayKey, !dayKeys.insert(key).inserted { throw BackupError.invalid("duplicate visit day.") }
            let session = record.sessionID.flatMap { sessions[$0] }
            let card = record.punchCardID.flatMap { cards[$0] }
            if let id = record.sessionID {
                guard session != nil, visitSessionIDs.insert(id).inserted else { throw BackupError.invalid("duplicate or missing visit session.") }
            }
            guard record.punchCardID == nil || card != nil else { throw BackupError.invalid("missing visit card.") }
            let model = try GymVisit(profile: profile, checkedInAt: record.checkedInAt, session: session, punchCard: card)
            record.apply(to: model); context.insert(model)
        }
        for record in archive.templates {
            guard let profile = record.profileID.flatMap({ profiles[$0] }), (1...20).contains(record.setsPerExercise),
                  Set(record.exerciseIDs).count == record.exerciseIDs.count,
                  record.exerciseIDs.allSatisfy({ exercises[$0] == nil || exercises[$0]?.profile?.id == profile.id }) else {
                throw BackupError.invalid("invalid template or exercise ownership.")
            }
            let model = WorkoutTemplate(profile: profile, name: record.name, exerciseIDs: record.exerciseIDs)
            record.apply(to: model); context.insert(model)
        }
    }

    static func csv(context: ModelContext) throws -> Data {
        func quoted(_ value: String) -> String {
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(where: { value.hasPrefix($0) }) ? "'" + value : value
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        let formatter = ISO8601DateFormatter()
        var rows = [["Profile", "Workout date", "Exercise", "Set", "Weight", "Unit", "Full reps", "Partial reps", "RPE", "Completed", "Warm-up", "Load convention", "Notes"]]
        for session in try context.fetch(FetchDescriptor<WorkoutSession>(sortBy: [SortDescriptor(\.startedAt)])) {
            for log in session.orderedLogs {
                for entry in log.orderedSets {
                    rows.append([session.profile?.name ?? "", formatter.string(from: session.startedAt), log.exerciseName,
                        String(entry.order + 1), String(entry.weight), log.unit.rawValue, String(entry.reps), String(entry.partialReps), entry.rpe.map { String($0) } ?? "",
                        entry.completedAt == nil ? "No" : "Yes", entry.isWarmUp ? "Yes" : "No", log.loadNotes ?? "", log.notes])
                }
            }
        }
        return Data(rows.map { $0.map(quoted).joined(separator: ",") }.joined(separator: "\r\n").utf8)
    }
}

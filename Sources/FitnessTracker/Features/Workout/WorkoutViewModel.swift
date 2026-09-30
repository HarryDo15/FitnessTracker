import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WorkoutViewModel {
    private let context: ModelContext
    let profile: Profile
    private(set) var session: WorkoutSession?
    private(set) var finishedSession: WorkoutSession?
    private var drafts: [UUID: SetDraft] = [:]
    private var lastLoggedSetID: UUID?
    var canUndoLastSet: Bool { session?.exerciseLogs.contains { $0.sets.contains { $0.id == lastLoggedSetID && $0.completedAt != nil } } == true }
    var errorMessage: String?

    init(profile: Profile, context: ModelContext) {
        self.profile = profile
        self.context = context
    }

    func restore() {
        guard session == nil else { return }
        let id = profile.id
        do {
            let sessions = try context.fetch(FetchDescriptor<WorkoutSession>(
                predicate: #Predicate { $0.profile?.id == id }, sortBy: [SortDescriptor(\WorkoutSession.startedAt, order: .reverse)]))
            session = sessions.first { $0.status == .active }
        } catch { errorMessage = error.localizedDescription }
    }

    func start(now: Date = .now) {
        restore()
        guard session == nil, errorMessage == nil else { return }
        let newSession = WorkoutSession(profile: profile, startedAt: now)
        context.insert(newSession)
        guard save() else { return }
        session = newSession
        finishedSession = nil
        drafts = [:]
    }

    func add(_ exercise: Exercise) {
        guard let session, session.status == .active,
              !session.exerciseLogs.contains(where: { $0.exercise?.id == exercise.id }) else { return }
        do {
            let log = try ExerciseLog(session: session, exercise: exercise,
                                      order: (session.exerciseLogs.map(\.order).max() ?? -1) + 1)
            context.insert(log)
            _ = save()
        } catch { errorMessage = error.localizedDescription }
    }

    /// Only completed working sets from this profile's latest completed occurrence.
    func previousSets(for log: ExerciseLog) -> [PreviousSet] {
        guard let session, let exercise = log.exercise else { return [] }
        let previous = exercise.logs.filter {
            $0.session?.profile?.id == profile.id && $0.session?.status == .completed &&
            ($0.session?.startedAt ?? .distantFuture) < session.startedAt &&
            $0.sets.contains { $0.completedAt != nil && !$0.isWarmUp && SetInputRules.isValid(weight: $0.weight, reps: $0.reps) }
        }.sorted {
            let left = $0.session?.startedAt ?? .distantPast
            let right = $1.session?.startedAt ?? .distantPast
            return left == right ? $0.order > $1.order : left > right
        }.first
        guard let previous else { return [] }
        return previous.orderedSets.filter { $0.completedAt != nil && !$0.isWarmUp && SetInputRules.isValid(weight: $0.weight, reps: $0.reps) }.map {
            PreviousSet(id: $0.id, weight: $0.weight, reps: $0.reps, unit: previous.unit)
        }
    }

    func draft(for log: ExerciseLog) -> SetDraft {
        if let draft = drafts[log.id] { return draft }
        if let planned = log.orderedSets.first(where: { $0.completedAt == nil }) {
            return SetDraft(weight: planned.weight, reps: planned.reps)
        }
        let previous = previousSets(for: log)
        let index = log.sets.filter { $0.completedAt != nil && !$0.isWarmUp }.count
        if previous.indices.contains(index) {
            let set = previous[index]
            let weight = WorkoutCalculations.convertedWeight(set.weight, from: set.unit, to: log.unit)
            return SetDraft(weight: (weight * 100).rounded() / 100, reps: set.reps)
        }
        if let last = log.orderedSets.last(where: { $0.completedAt != nil && !$0.isWarmUp }) {
            return SetDraft(weight: last.weight, reps: last.reps)
        }
        if let exercise = log.exercise, let starting = ExerciseStartingValues.draft(for: exercise, in: log.unit) {
            return starting
        }
        return SetDraft(weight: 0, reps: log.targetRepMinimum)
    }

    func updateDraft(_ draft: SetDraft, for log: ExerciseLog) {
        drafts[log.id] = draft
    }

    func logSet(for log: ExerciseLog, now: Date = .now) {
        guard let session, session.status == .active, log.session?.id == session.id else { return }
        let draft = draft(for: log)
        do {
            guard SetInputRules.isValid(weight: draft.weight, reps: draft.reps) else { throw ModelValidationError.invalidSet }
            let entry: SetEntry
            if let planned = log.orderedSets.first(where: { $0.completedAt == nil }) {
                entry = planned
                entry.weight = draft.weight
                entry.reps = draft.reps
                entry.completedAt = now
            } else {
                entry = try SetEntry(log: log, order: (log.sets.map(\.order).max() ?? -1) + 1,
                                     weight: draft.weight, reps: draft.reps, completedAt: now)
                context.insert(entry)
            }
            session.restEndsAt = now.addingTimeInterval(180)
            guard save() else { return }
            lastLoggedSetID = entry.id
            syncRestAlert()
            drafts.removeValue(forKey: log.id)
        } catch { errorMessage = error.localizedDescription }
    }

    func extendRest(now: Date = .now) {
        guard let session, session.status == .active else { return }
        session.restEndsAt = max(session.restEndsAt ?? now, now).addingTimeInterval(30)
        if save() { syncRestAlert() }
    }

    func skipRest() {
        session?.restEndsAt = nil
        if save() { syncRestAlert() }
    }

    func finish(now: Date = .now) {
        guard let session, session.status == .active,
              session.exerciseLogs.contains(where: { $0.sets.contains { $0.completedAt != nil } }) else { return }
        session.endedAt = max(now, session.startedAt)
        session.status = .completed
        session.restEndsAt = nil
        guard save() else { return }
        RestAlerts.shared.cancel(sessionID: session.id)
        finishedSession = session
        self.session = nil
        drafts = [:]
    }

    func dismissSummary() { finishedSession = nil }

    func discardEmptyWorkout() {
        guard let session, session.status == .active,
              !session.exerciseLogs.contains(where: { $0.sets.contains { $0.completedAt != nil } }) else { return }
        let deletedID = session.id
        context.delete(session)
        guard save() else { return }
        RestAlerts.shared.cancel(sessionID: deletedID)
        self.session = nil
        drafts = [:]
    }

    func syncRestAlert() {
        guard let session else { return }
        RestAlerts.shared.schedule(sessionID: session.id, profileName: profile.name, deadline: session.restEndsAt)
    }

    func undoLastSet() {
        guard let session, let log = session.exerciseLogs.first(where: { $0.sets.contains { $0.id == lastLoggedSetID } }),
              let set = log.sets.first(where: { $0.id == lastLoggedSetID }) else { return }
        set.completedAt = nil
        session.restEndsAt = nil
        guard save() else { return }
        drafts.removeValue(forKey: log.id)
        lastLoggedSetID = nil
        syncRestAlert()
    }

    var lastWorkout: WorkoutSession? {
        profile.sessions.filter { $0.status == .completed && $0.exerciseLogs.contains { $0.exercise != nil && $0.sets.contains { $0.completedAt != nil } } }
            .max { $0.startedAt < $1.startedAt }
    }

    func repeatLastWorkout() {
        guard let previous = lastWorkout else { return }
        let items = previous.orderedLogs.compactMap { log -> (Exercise, Int)? in
            guard let exercise = log.exercise, !exercise.isArchived, exercise.profile?.id == profile.id else { return nil }
            return (exercise, max(1, log.sets.filter { $0.completedAt != nil && !$0.isWarmUp }.count))
        }
        startPlanned(items)
    }

    func start(template: WorkoutTemplate) {
        guard template.profile?.id == profile.id else { return }
        startPlanned(template.exerciseIDs.compactMap { id in
            profile.exercises.first { $0.id == id && !$0.isArchived }.map { ($0, template.setsPerExercise) }
        })
    }

    private func startPlanned(_ items: [(Exercise, Int)]) {
        restore()
        guard session == nil else { return } // Never append a repeated routine to an unfinished workout.
        guard !items.isEmpty else { errorMessage = "This routine has no available exercises. Edit it first."; return }
        let newSession = WorkoutSession(profile: profile)
        context.insert(newSession)
        do {
            var added: Set<UUID> = []
            for (exercise, count) in items where added.insert(exercise.id).inserted {
                let log = try ExerciseLog(session: newSession, exercise: exercise, order: added.count - 1)
                context.insert(log)
                let targets = ExerciseProgress.targets(for: log)
                let initial = ExerciseStartingValues.draft(for: exercise, in: log.unit) ?? SetDraft(weight: 0, reps: log.targetRepMinimum)
                for index in 0..<min(20, max(1, count)) {
                    let target = targets.isEmpty ? nil : targets[min(index, targets.count - 1)]
                    context.insert(try SetEntry(log: log, order: index, weight: target?.weight ?? initial.weight,
                                               reps: target?.reps ?? initial.reps))
                }
            }
            guard save() else { return }
            session = newSession
            finishedSession = nil
            drafts = [:]
        } catch {
            context.rollback()
            errorMessage = error.localizedDescription
        }
    }

    @discardableResult private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            errorMessage = "Your change could not be saved. Please try again. \(error.localizedDescription)"
            return false
        }
    }
}

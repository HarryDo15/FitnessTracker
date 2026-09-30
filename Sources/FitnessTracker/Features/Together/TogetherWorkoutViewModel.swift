import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class TogetherWorkoutViewModel {
    let models: [WorkoutViewModel]
    var selectedProfileID: UUID
    var selectedLogIDs: [UUID: UUID] = [:]
    var hasStarted = false
    var finished = false

    init(profiles: [Profile], context: ModelContext) {
        precondition(!profiles.isEmpty)
        models = profiles.map { WorkoutViewModel(profile: $0, context: context) }
        selectedProfileID = profiles[0].id
    }

    var current: WorkoutViewModel { models.first { $0.profile.id == selectedProfileID } ?? models[0] }
    var currentLog: ExerciseLog? { current.session?.exerciseLogs.first { $0.id == selectedLogIDs[current.profile.id] } }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        for model in models { model.start() }
        if let first = current.session?.orderedLogs.first { select(first, for: current) }
    }

    func select(_ log: ExerciseLog, for source: WorkoutViewModel) {
        selectedLogIDs[source.profile.id] = log.id
        let name = normalized(log.exercise?.name ?? log.exerciseName)
        for partner in models where partner.profile.id != source.profile.id {
            guard let session = partner.session else { continue }
            if let match = session.orderedLogs.first(where: { normalized($0.exercise?.name ?? $0.exerciseName) == name }) {
                selectedLogIDs[partner.profile.id] = match.id
            } else if let exercise = partner.profile.exercises.first(where: { !$0.isArchived && normalized($0.name) == name }) {
                partner.add(exercise)
                selectedLogIDs[partner.profile.id] = session.exerciseLogs.first { $0.exercise?.id == exercise.id }?.id
            } else {
                selectedLogIDs.removeValue(forKey: partner.profile.id)
            }
        }
    }

    func choose(_ exercise: Exercise, for model: WorkoutViewModel, matchPartner: Bool) {
        model.add(exercise)
        guard let log = model.session?.exerciseLogs.first(where: { $0.exercise?.id == exercise.id }) else { return }
        if matchPartner { select(log, for: model) }
        else { selectedLogIDs[model.profile.id] = log.id }
    }

    func nextTurn() {
        guard let index = models.firstIndex(where: { $0.profile.id == selectedProfileID }) else { return }
        selectedProfileID = models[(index + 1) % models.count].profile.id
    }

    func finish() {
        for model in models {
            if model.session?.exerciseLogs.contains(where: { $0.sets.contains { $0.completedAt != nil } }) == true { model.finish() }
            else { model.discardEmptyWorkout() }
        }
        finished = models.allSatisfy { $0.session == nil }
    }

    private func normalized(_ name: String) -> String { name.lowercased().filter { $0.isLetter || $0.isNumber } }
}

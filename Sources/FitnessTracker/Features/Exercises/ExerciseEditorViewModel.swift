import Foundation
import Observation
import SwiftData

enum ExerciseEditorError: LocalizedError {
    case missingName, duplicateName, invalidPhoto, missingProfile
    var errorDescription: String? {
        switch self {
        case .missingName: return "Enter an exercise name (up to 100 characters)."
        case .duplicateName: return "This profile already has an exercise with that name. Choose another name or edit the existing exercise."
        case .invalidPhoto: return "Choose a supported image smaller than 50 MB."
        case .missingProfile: return "This exercise’s profile is unavailable. Please select a profile again."
        }
    }
}

@MainActor
@Observable
final class ExerciseEditorViewModel {
    var name: String
    var muscleGroup: String
    var equipment: String
    var unit: WeightUnit
    var isAssisted: Bool
    var setupNotes: String
    var isFavorite: Bool
    var loadNotes: String
    var photoData: Data?
    var errorMessage: String?
    var isLoadingPhoto = false
    private let exercise: Exercise?
    let profileID: UUID
    var isEditing: Bool { exercise != nil }
    var canSave: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100 && !isLoadingPhoto
    }

    init(profileID: UUID, exercise: Exercise? = nil) {
        self.profileID = profileID
        self.exercise = exercise
        name = exercise?.name ?? ""
        muscleGroup = exercise?.muscleGroup ?? ""
        equipment = exercise?.equipment ?? ""
        unit = exercise?.unit ?? .kg
        isAssisted = exercise?.isAssisted ?? false
        loadNotes = exercise?.loadNotes ?? ""
        setupNotes = exercise?.setupNotes ?? ""
        isFavorite = exercise?.isFavorite ?? false
        photoData = exercise?.photoData
    }

    @discardableResult func save(in context: ModelContext) -> Exercise? {
        do {
            guard canSave else { throw ExerciseEditorError.missingName }
            let ownerID = profileID
            guard let profile = try context.fetch(FetchDescriptor<Profile>(predicate: #Predicate { $0.id == ownerID })).first,
                  exercise == nil || exercise?.profile?.id == ownerID else { throw ExerciseEditorError.missingProfile }
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let owned = try context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.profile?.id == ownerID }))
            guard !owned.contains(where: {
                $0.id != exercise?.id && $0.name.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(trimmedName) == .orderedSame
            }) else { throw ExerciseEditorError.duplicateName }
            let edited = exercise ?? Exercise(name: trimmedName, muscleGroup: "", equipment: "", unit: unit, profile: profile)
            if exercise == nil { context.insert(edited) }
            if edited.unit != unit {
                edited.weightIncrement = (WorkoutCalculations.convertedWeight(edited.weightIncrement, from: edited.unit, to: unit) * 100).rounded() / 100
            }
            edited.name = trimmedName
            edited.muscleGroup = muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Other" : muscleGroup.trimmingCharacters(in: .whitespacesAndNewlines)
            edited.equipment = equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Unspecified" : equipment.trimmingCharacters(in: .whitespacesAndNewlines)
            edited.unit = unit
            edited.isAssisted = isAssisted
            edited.loadNotes = loadNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            edited.setupNotes = setupNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            edited.isFavorite = isFavorite
            edited.photoData = photoData
            do { try context.save() }
            catch { context.rollback(); throw error }
            return edited
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

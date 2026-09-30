import Foundation
import SwiftData

/// Versioned, portable JSON with embedded photos and stable relationship IDs.
struct FitnessBackup: Codable {
    var version = 2
    var exportedAt = Date.now
    var profiles: [ProfileRecord]
    var exercises: [ExerciseRecord]
    var sessions: [WorkoutSessionRecord]
    var logs: [ExerciseLogRecord]
    var sets: [SetEntryRecord]
    var cards: [PunchCardRecord]
    var rewards: [RewardRecord]
    var visits: [GymVisitRecord]
    var templates: [WorkoutTemplateRecord]

    @MainActor init(context: ModelContext) throws {
        profiles = try context.fetch(FetchDescriptor<Profile>()).map(ProfileRecord.init)
        exercises = try context.fetch(FetchDescriptor<Exercise>()).map(ExerciseRecord.init)
        sessions = try context.fetch(FetchDescriptor<WorkoutSession>()).map(WorkoutSessionRecord.init)
        logs = try context.fetch(FetchDescriptor<ExerciseLog>()).map(ExerciseLogRecord.init)
        sets = try context.fetch(FetchDescriptor<SetEntry>()).map(SetEntryRecord.init)
        cards = try context.fetch(FetchDescriptor<PunchCard>()).map(PunchCardRecord.init)
        rewards = try context.fetch(FetchDescriptor<Reward>()).map(RewardRecord.init)
        visits = try context.fetch(FetchDescriptor<GymVisit>()).map(GymVisitRecord.init)
        templates = try context.fetch(FetchDescriptor<WorkoutTemplate>()).map(WorkoutTemplateRecord.init)
    }
}

struct ProfileRecord: Codable {
    var id: UUID
    var name: String
    var symbolName: String
    var avatarData: Data?
    var createdAt: Date
    var librarySeedVersion: Int
    var punchCardEnabled: Bool
    var rewardMessage: String
    var gymRewardsSetupVersion: Int
    var startingValuesSeedVersion: Int
    var initialPunchesSeedVersion: Int
    var personalNameSeedVersion: Int
    var baselineWorkoutSeedVersion: Int
    var haiLibrarySeedVersion: Int
    var partialRepSeedVersion: Int?
    var perSideLoadCorrectionVersion: Int

    @MainActor init(_ model: Profile) {
        id = model.id
        name = model.name
        symbolName = model.symbolName
        avatarData = model.avatarData
        createdAt = model.createdAt
        librarySeedVersion = model.librarySeedVersion
        punchCardEnabled = model.punchCardEnabled
        rewardMessage = model.rewardMessage
        gymRewardsSetupVersion = model.gymRewardsSetupVersion
        startingValuesSeedVersion = model.startingValuesSeedVersion
        initialPunchesSeedVersion = model.initialPunchesSeedVersion
        personalNameSeedVersion = model.personalNameSeedVersion
        baselineWorkoutSeedVersion = model.baselineWorkoutSeedVersion
        haiLibrarySeedVersion = model.haiLibrarySeedVersion
        partialRepSeedVersion = model.partialRepSeedVersion
        perSideLoadCorrectionVersion = model.perSideLoadCorrectionVersion
    }

    @MainActor func apply(to model: Profile) {
        model.id = id
        model.name = name
        model.symbolName = symbolName
        model.avatarData = avatarData
        model.createdAt = createdAt
        model.librarySeedVersion = librarySeedVersion
        model.punchCardEnabled = punchCardEnabled
        model.rewardMessage = rewardMessage
        model.gymRewardsSetupVersion = gymRewardsSetupVersion
        model.startingValuesSeedVersion = startingValuesSeedVersion
        model.initialPunchesSeedVersion = initialPunchesSeedVersion
        model.personalNameSeedVersion = personalNameSeedVersion
        model.baselineWorkoutSeedVersion = baselineWorkoutSeedVersion
        model.haiLibrarySeedVersion = haiLibrarySeedVersion
        model.partialRepSeedVersion = partialRepSeedVersion ?? 0
        model.perSideLoadCorrectionVersion = perSideLoadCorrectionVersion
    }
}

struct ExerciseRecord: Codable {
    var id: UUID
    var name: String
    var muscleGroup: String
    var equipment: String
    var unit: WeightUnit
    var weightIncrement: Double
    var targetRepMinimum: Int
    var targetRepMaximum: Int
    var startingWeight: Double?
    var startingReps: Int?
    var startingUnit: WeightUnit?
    var startingNotes: String
    var loadNotes: String
    var setupNotes: String
    var isFavorite: Bool
    var photoData: Data?
    var isAssisted: Bool
    var isArchived: Bool
    var profileID: UUID?

    @MainActor init(_ model: Exercise) {
        id = model.id
        name = model.name
        muscleGroup = model.muscleGroup
        equipment = model.equipment
        unit = model.unit
        weightIncrement = model.weightIncrement
        targetRepMinimum = model.targetRepMinimum
        targetRepMaximum = model.targetRepMaximum
        startingWeight = model.startingWeight
        startingReps = model.startingReps
        startingUnit = model.startingUnit
        startingNotes = model.startingNotes
        loadNotes = model.loadNotes
        setupNotes = model.setupNotes
        isFavorite = model.isFavorite
        photoData = model.photoData
        isAssisted = model.isAssisted
        isArchived = model.isArchived
        profileID = model.profile?.id
    }

    @MainActor func apply(to model: Exercise) {
        model.id = id
        model.name = name
        model.muscleGroup = muscleGroup
        model.equipment = equipment
        model.unit = unit
        model.weightIncrement = weightIncrement
        model.targetRepMinimum = targetRepMinimum
        model.targetRepMaximum = targetRepMaximum
        model.startingWeight = startingWeight
        model.startingReps = startingReps
        model.startingUnit = startingUnit
        model.startingNotes = startingNotes
        model.loadNotes = loadNotes
        model.setupNotes = setupNotes
        model.isFavorite = isFavorite
        model.photoData = photoData
        model.isAssisted = isAssisted
        model.isArchived = isArchived
    }
}

struct WorkoutSessionRecord: Codable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var status: WorkoutStatus
    var restEndsAt: Date?
    var isDateOnlyImport: Bool
    var profileID: UUID?

    @MainActor init(_ model: WorkoutSession) {
        id = model.id
        startedAt = model.startedAt
        endedAt = model.endedAt
        notes = model.notes
        status = model.status
        restEndsAt = model.restEndsAt
        isDateOnlyImport = model.isDateOnlyImport
        profileID = model.profile?.id
    }

    @MainActor func apply(to model: WorkoutSession) {
        model.id = id
        model.startedAt = startedAt
        model.endedAt = endedAt
        model.notes = notes
        model.status = status
        model.restEndsAt = restEndsAt
        model.isDateOnlyImport = isDateOnlyImport
    }
}

struct ExerciseLogRecord: Codable {
    var id: UUID
    var order: Int
    var notes: String
    var targetRepMinimum: Int
    var targetRepMaximum: Int
    var weightIncrement: Double?
    var loadNotes: String?
    var muscleGroup: String?
    var exerciseName: String
    var unit: WeightUnit
    var isAssisted: Bool
    var sessionID: UUID?
    var exerciseID: UUID?

    @MainActor init(_ model: ExerciseLog) {
        id = model.id
        order = model.order
        notes = model.notes
        targetRepMinimum = model.targetRepMinimum
        targetRepMaximum = model.targetRepMaximum
        weightIncrement = model.weightIncrement
        loadNotes = model.loadNotes
        muscleGroup = model.muscleGroup
        exerciseName = model.exerciseName
        unit = model.unit
        isAssisted = model.isAssisted
        sessionID = model.session?.id
        exerciseID = model.exercise?.id
    }

    @MainActor func apply(to model: ExerciseLog) {
        model.id = id
        model.order = order
        model.notes = notes
        model.targetRepMinimum = targetRepMinimum
        model.targetRepMaximum = targetRepMaximum
        model.weightIncrement = weightIncrement
        model.loadNotes = loadNotes
        model.muscleGroup = muscleGroup
        model.exerciseName = exerciseName
        model.unit = unit
        model.isAssisted = isAssisted
    }
}

struct SetEntryRecord: Codable {
    var id: UUID
    var order: Int
    var weight: Double
    var partialReps: Int?
    var reps: Int
    var rpe: Double?
    var completedAt: Date?
    var isWarmUp: Bool
    var logID: UUID?

    @MainActor init(_ model: SetEntry) {
        id = model.id
        order = model.order
        weight = model.weight
        partialReps = model.partialReps
        reps = model.reps
        rpe = model.rpe
        completedAt = model.completedAt
        isWarmUp = model.isWarmUp
        logID = model.log?.id
    }

    @MainActor func apply(to model: SetEntry) {
        model.id = id
        model.order = order
        model.weight = weight
        model.partialReps = partialReps ?? 0
        model.reps = reps
        model.rpe = rpe
        model.completedAt = completedAt
        model.isWarmUp = isWarmUp
    }
}

struct PunchCardRecord: Codable {
    var id: UUID
    var title: String
    var requiredVisits: Int
    var startedAt: Date
    var completedAt: Date?
    var archivedAt: Date?
    var carriedOverPunches: Int
    var profileID: UUID?

    @MainActor init(_ model: PunchCard) {
        id = model.id
        title = model.title
        requiredVisits = model.requiredVisits
        startedAt = model.startedAt
        completedAt = model.completedAt
        archivedAt = model.archivedAt
        carriedOverPunches = model.carriedOverPunches
        profileID = model.profile?.id
    }

    @MainActor func apply(to model: PunchCard) {
        model.id = id
        model.title = title
        model.requiredVisits = requiredVisits
        model.startedAt = startedAt
        model.completedAt = completedAt
        model.archivedAt = archivedAt
        model.carriedOverPunches = carriedOverPunches
    }
}

struct RewardRecord: Codable {
    var id: UUID
    var title: String
    var details: String
    var earnedAt: Date?
    var redeemedAt: Date?
    var profileID: UUID?
    var punchCardID: UUID?

    @MainActor init(_ model: Reward) {
        id = model.id
        title = model.title
        details = model.details
        earnedAt = model.earnedAt
        redeemedAt = model.redeemedAt
        profileID = model.profile?.id
        punchCardID = model.punchCard?.id
    }

    @MainActor func apply(to model: Reward) {
        model.id = id
        model.title = title
        model.details = details
        model.earnedAt = earnedAt
        model.redeemedAt = redeemedAt
    }
}

struct GymVisitRecord: Codable {
    var id: UUID
    var checkedInAt: Date
    var dayKey: String?
    var eligibleForPunch: Bool
    var punchedAt: Date?
    var profileID: UUID?
    var sessionID: UUID?
    var punchCardID: UUID?

    @MainActor init(_ model: GymVisit) {
        id = model.id
        checkedInAt = model.checkedInAt
        dayKey = model.dayKey
        eligibleForPunch = model.eligibleForPunch
        punchedAt = model.punchedAt
        profileID = model.profile?.id
        sessionID = model.session?.id
        punchCardID = model.punchCard?.id
    }

    @MainActor func apply(to model: GymVisit) {
        model.id = id
        model.checkedInAt = checkedInAt
        model.dayKey = dayKey
        model.eligibleForPunch = eligibleForPunch
        model.punchedAt = punchedAt
    }
}

struct WorkoutTemplateRecord: Codable {
    var id: UUID
    var name: String
    var exerciseIDs: [UUID]
    var setsPerExercise: Int
    var profileID: UUID?

    @MainActor init(_ model: WorkoutTemplate) {
        id = model.id
        name = model.name
        exerciseIDs = model.exerciseIDs
        setsPerExercise = model.setsPerExercise
        profileID = model.profile?.id
    }

    @MainActor func apply(to model: WorkoutTemplate) {
        model.id = id
        model.name = name
        model.exerciseIDs = exerciseIDs
        model.setsPerExercise = setsPerExercise
    }
}

import Foundation
import SwiftData

@Model
public final class SetEntry {
    @Attribute(.unique) public var id: UUID
    public var order: Int
    public var weight: Double
    public var reps: Int
    public var rpe: Double?
    /// Nil means planned/incomplete; a date records when the set was completed.
    public var completedAt: Date?
    public var isWarmUp: Bool
    public var log: ExerciseLog?

    public init(log: ExerciseLog, order: Int, weight: Double, reps: Int, rpe: Double? = nil,
                completedAt: Date? = nil, isWarmUp: Bool = false) throws {
        guard SetInputRules.isValid(weight: weight, reps: reps, completed: completedAt != nil),
              rpe.map({ $0.isFinite && (1...10).contains($0) }) ?? true else { throw ModelValidationError.invalidSet }
        self.id = UUID()
        self.log = log
        self.order = order
        self.weight = weight
        self.reps = reps
        self.rpe = rpe
        self.completedAt = completedAt
        self.isWarmUp = isWarmUp
    }
}

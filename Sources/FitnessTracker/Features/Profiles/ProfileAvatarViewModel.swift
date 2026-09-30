import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ProfileAvatarViewModel {
    var avatarData: Data?
    var isLoading = false
    var errorMessage: String?
    let profile: Profile

    init(profile: Profile) {
        self.profile = profile
        avatarData = profile.avatarData
    }

    func save(in context: ModelContext) -> Bool {
        guard !isLoading else { return false }
        let previous = profile.avatarData
        profile.avatarData = avatarData
        do {
            try context.save()
            return true
        } catch {
            profile.avatarData = previous
            errorMessage = error.localizedDescription
            return false
        }
    }
}

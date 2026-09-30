import Foundation
import Observation

@MainActor
@Observable
public final class ProfileContext {
    public private(set) var selectedProfileID: UUID?
    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = .standard) {
        self.defaults = defaults
        selectedProfileID = defaults?.string(forKey: "selectedProfileID").flatMap(UUID.init(uuidString:))
    }

    public func select(_ profile: Profile) {
        selectedProfileID = profile.id
        defaults?.set(profile.id.uuidString, forKey: "selectedProfileID")
    }

    public func restore(from profiles: [Profile]) {
        guard !profiles.isEmpty else {
            selectedProfileID = nil
            defaults?.removeObject(forKey: "selectedProfileID")
            return
        }
        if !profiles.contains(where: { $0.id == selectedProfileID }), let first = profiles.first {
            select(first)
        }
    }
}

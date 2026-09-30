import Foundation
#if os(iOS)
import UIKit
#endif

@MainActor
enum GymHaptics {
    static func announce(_ message: String) {
        #if os(iOS)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
    static func punch() {
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
    static func celebrate() {
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }
}

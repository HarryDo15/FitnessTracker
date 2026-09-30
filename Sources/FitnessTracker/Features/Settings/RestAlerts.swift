import Foundation
import UserNotifications

@MainActor
final class RestAlerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = RestAlerts()
    private var revisions: [UUID: UUID] = [:]
    private var enabled: Bool { UserDefaults.standard.bool(forKey: "restAlertsEnabled") }

    func enable() async throws -> Bool {
        #if os(iOS)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let allowed = try await center.requestAuthorization(options: [.alert, .sound])
        UserDefaults.standard.set(allowed, forKey: "restAlertsEnabled")
        return allowed
        #else
        return false
        #endif
    }

    func disable() {
        UserDefaults.standard.set(false, forKey: "restAlertsEnabled")
        revisions.removeAll()
        #if os(iOS)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        #endif
    }

    func cancel(sessionID: UUID) {
        revisions[sessionID] = UUID()
        #if os(iOS)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [sessionID.uuidString])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [sessionID.uuidString])
        #endif
    }

    func schedule(sessionID: UUID, profileName: String, deadline: Date?) {
        cancel(sessionID: sessionID)
        guard enabled, let deadline, deadline > .now else { return }
        #if os(iOS)
        let revision = UUID()
        revisions[sessionID] = revision
        Task {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            let settings = await center.notificationSettings()
            guard enabled, revisions[sessionID] == revision,
                  [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus), deadline > .now else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete, \(profileName)"
            content.body = "Ready for your next set."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, deadline.timeIntervalSinceNow), repeats: false)
            let request = UNNotificationRequest(identifier: sessionID.uuidString, content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
        #endif
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

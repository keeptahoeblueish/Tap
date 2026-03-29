import Foundation
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var onResponse: ((String, Bool) -> Void)?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func registerCategories() {
        let categories = buildCategories()
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }

    func send(_ event: TapEvent) {
        let content = buildContent(for: event)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    func buildContent(for event: TapEvent) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.sound = .default
        content.userInfo["event_id"] = event.id

        switch event.type {
        case .permission:
            content.title = "Permission Needed"
            content.categoryIdentifier = "PERMISSION"
            content.interruptionLevel = .timeSensitive
        case .blocker:
            content.title = "Action Needed"
            content.categoryIdentifier = "INFO"
            content.interruptionLevel = .timeSensitive
        case .complete:
            content.title = "Task Complete"
            content.categoryIdentifier = "INFO"
            content.interruptionLevel = .active
        case .error:
            content.title = "Error"
            content.categoryIdentifier = "INFO"
            content.interruptionLevel = .timeSensitive
        }

        content.body = event.message
        return content
    }

    func buildCategories() -> Set<UNNotificationCategory> {
        let approveAction = UNNotificationAction(identifier: "APPROVE", title: "Approve", options: .foreground)
        let denyAction = UNNotificationAction(identifier: "DENY", title: "Deny", options: .destructive)
        let permissionCategory = UNNotificationCategory(
            identifier: "PERMISSION",
            actions: [approveAction, denyAction],
            intentIdentifiers: [],
            options: []
        )

        let infoCategory = UNNotificationCategory(
            identifier: "INFO",
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        return [permissionCategory, infoCategory]
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let eventId = response.notification.request.identifier
        let approved = response.actionIdentifier == "APPROVE"
        onResponse?(eventId, approved)
        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

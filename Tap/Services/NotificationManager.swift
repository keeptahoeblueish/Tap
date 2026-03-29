import Foundation
import UserNotifications
import AppKit

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    var onResponse: ((String, Bool) -> Void)?
    private var centerAvailable = false

    override init() {
        super.init()
    }

    private func getCenter() -> UNUserNotificationCenter? {
        // UNUserNotificationCenter crashes if not running in an app bundle
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        let center = UNUserNotificationCenter.current()
        if !centerAvailable {
            center.delegate = self
            centerAvailable = true
        }
        return center
    }

    func requestPermission() {
        getCenter()?.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Tap: notification permission error: \(error.localizedDescription)")
            }
        }
    }

    func registerCategories() {
        let categories = Self.buildCategories()
        getCenter()?.setNotificationCategories(categories)
    }

    func send(_ event: TapEvent) {
        let content = Self.buildContent(for: event)
        let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
        getCenter()?.add(request) { error in
            if let error = error {
                print("Tap: notification error: \(error.localizedDescription)")
            }
        }

        // Bounce the Dock icon to grab attention
        DispatchQueue.main.async {
            switch event.type {
            case .permission, .blocker, .error:
                // Keep bouncing until the user clicks
                NSApp.requestUserAttention(.criticalRequest)
            case .complete:
                // Single bounce
                NSApp.requestUserAttention(.informationalRequest)
            }
        }
    }

    static func buildContent(for event: TapEvent) -> UNMutableNotificationContent {
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

    static func buildCategories() -> Set<UNNotificationCategory> {
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

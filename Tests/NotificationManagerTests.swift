import XCTest
import UserNotifications
@testable import Tap

final class NotificationManagerTests: XCTestCase {
    func testNotificationCategorySetup() {
        let categories = NotificationManager.buildCategories()

        let permissionCategory = categories.first { $0.identifier == "PERMISSION" }
        XCTAssertNotNil(permissionCategory)
        XCTAssertEqual(permissionCategory?.actions.count, 2)
        let actionIds = permissionCategory?.actions.map(\.identifier)
        XCTAssertTrue(actionIds?.contains("APPROVE") ?? false)
        XCTAssertTrue(actionIds?.contains("DENY") ?? false)

        let infoCategory = categories.first { $0.identifier == "INFO" }
        XCTAssertNotNil(infoCategory)
        XCTAssertEqual(infoCategory?.actions.count, 0)
    }

    func testNotificationContentForPermission() {
        let event = TapEvent(type: .permission, id: "evt_001", toolName: "Bash", toolInput: "git push origin main", message: "Claude wants to run: git push origin main", timestamp: Date().timeIntervalSince1970)
        let content = NotificationManager.buildContent(for: event)
        XCTAssertEqual(content.title, "Permission Needed")
        XCTAssertEqual(content.body, "Claude wants to run: git push origin main")
        XCTAssertEqual(content.categoryIdentifier, "PERMISSION")
        XCTAssertEqual(content.userInfo["event_id"] as? String, "evt_001")
    }

    func testNotificationContentForError() {
        let event = TapEvent(type: .error, id: "evt_002", toolName: nil, toolInput: nil, message: "Build failed: TypeScript error", timestamp: Date().timeIntervalSince1970)
        let content = NotificationManager.buildContent(for: event)
        XCTAssertEqual(content.title, "Error")
        XCTAssertEqual(content.categoryIdentifier, "INFO")
    }

    func testNotificationContentForComplete() {
        let event = TapEvent(type: .complete, id: "evt_003", toolName: nil, toolInput: nil, message: "Deployed to preview", timestamp: Date().timeIntervalSince1970)
        let content = NotificationManager.buildContent(for: event)
        XCTAssertEqual(content.title, "Task Complete")
        XCTAssertEqual(content.categoryIdentifier, "INFO")
    }

    func testNotificationContentForBlocker() {
        let event = TapEvent(type: .blocker, id: "evt_004", toolName: nil, toolInput: nil, message: "Action needed now", timestamp: Date().timeIntervalSince1970)
        let content = NotificationManager.buildContent(for: event)
        XCTAssertEqual(content.title, "Action Needed")
        XCTAssertEqual(content.categoryIdentifier, "INFO")
    }
}

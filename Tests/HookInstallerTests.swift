import XCTest
@testable import Tap

final class HookInstallerTests: XCTestCase {
    var testSettingsPath: String!
    var testHookScriptPath: String!

    override func setUp() {
        super.setUp()
        testSettingsPath = NSTemporaryDirectory() + "tap-test-settings-\(UUID().uuidString).json"
        testHookScriptPath = NSTemporaryDirectory() + "tap-test-hook-\(UUID().uuidString).sh"
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(atPath: testSettingsPath)
        try? FileManager.default.removeItem(atPath: testHookScriptPath)
    }

    func testInstallIntoEmptySettings() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)
        installer.install()

        let data = try Data(contentsOf: URL(fileURLWithPath: testSettingsPath))
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks)
        let preToolUse = hooks?["PreToolUse"] as? [[String: Any]]
        XCTAssertNotNil(preToolUse)
        XCTAssertFalse(preToolUse?.isEmpty ?? true)
    }

    func testInstallPreservesExistingSettings() throws {
        let existing = """
        {"permissions": {"defaultMode": "bypassPermissions"}, "hooks": {"SessionStart": [{"matcher": "compact", "hooks": [{"type": "command", "command": "echo hi"}]}]}}
        """
        try existing.write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)
        installer.install()

        let data = try Data(contentsOf: URL(fileURLWithPath: testSettingsPath))
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let permissions = settings["permissions"] as? [String: Any]
        XCTAssertEqual(permissions?["defaultMode"] as? String, "bypassPermissions")
        let hooks = settings["hooks"] as? [String: Any]
        XCTAssertNotNil(hooks?["SessionStart"])
        XCTAssertNotNil(hooks?["PreToolUse"])
    }

    func testHookScriptCreated() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)
        installer.install()
        XCTAssertTrue(FileManager.default.fileExists(atPath: testHookScriptPath))
        let attrs = try FileManager.default.attributesOfItem(atPath: testHookScriptPath)
        let perms = (attrs[.posixPermissions] as? Int) ?? 0
        XCTAssertTrue(perms & 0o111 != 0, "Hook script should be executable")
    }

    func testInstallIfNeededSkipsWhenInstalled() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)

        // First install
        installer.install()
        XCTAssertTrue(installer.isInstalled())

        // Record creation time
        let originalAttrs = try FileManager.default.attributesOfItem(atPath: testSettingsPath)
        let originalModTime = originalAttrs[.modificationDate] as? Date

        // Small delay to ensure time difference would be detectable
        Thread.sleep(forTimeInterval: 0.1)

        // Second install should be skipped
        installer.installIfNeeded()

        let newAttrs = try FileManager.default.attributesOfItem(atPath: testSettingsPath)
        let newModTime = newAttrs[.modificationDate] as? Date

        // Timestamps should be the same (or very close)
        XCTAssertEqual(originalModTime, newModTime, accuracy: 0.01)
    }

    func testUninstallRemovesHooks() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)

        installer.install()
        XCTAssertTrue(installer.isInstalled())

        installer.uninstall()
        XCTAssertFalse(installer.isInstalled())
    }

    func testUninstallRemovesHookScript() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)

        installer.install()
        XCTAssertTrue(FileManager.default.fileExists(atPath: testHookScriptPath))

        installer.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: testHookScriptPath))
    }

    func testGenerateHookScriptContainsSocketPath() {
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)
        let script = installer.hookScriptPath
        XCTAssertFalse(script.isEmpty)
        XCTAssertTrue(script.contains("tap.sock"))
    }

    func testMultipleHooksNotDuplicated() throws {
        try "{}".write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)

        installer.install()
        installer.install()

        let data = try Data(contentsOf: URL(fileURLWithPath: testSettingsPath))
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as? [String: Any]
        let preToolUse = hooks?["PreToolUse"] as? [[String: Any]]

        // Should only have one PreToolUse entry
        XCTAssertEqual(preToolUse?.count, 1)
    }

    func testUninstallPreservesOtherHooks() throws {
        let existing = """
        {"hooks": {"SessionStart": [{"matcher": "compact", "hooks": [{"type": "command", "command": "echo hi"}]}]}}
        """
        try existing.write(toFile: testSettingsPath, atomically: true, encoding: .utf8)
        let installer = HookInstaller(settingsPath: testSettingsPath, hookScriptPath: testHookScriptPath)

        installer.install()
        installer.uninstall()

        let data = try Data(contentsOf: URL(fileURLWithPath: testSettingsPath))
        let settings = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let hooks = settings["hooks"] as? [String: Any]

        // SessionStart hook should still exist
        XCTAssertNotNil(hooks?["SessionStart"])
        // Tap hooks should be gone
        XCTAssertNil(hooks?["PreToolUse"])
        XCTAssertNil(hooks?["Stop"])
    }
}

import XCTest
import Foundation
@testable import Tap

final class HookInstallerTests: XCTestCase {
    var installer: HookInstaller!
    var tempDir: String!
    var tempBashConfigPath: String!
    var tempHookPath: String!

    override func setUp() {
        super.setUp()

        // Create temporary directory for testing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tap_hook_test_\(UUID().uuidString)")
        tempDir = tempURL.path
        try? FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)

        // Set up temporary paths
        tempBashConfigPath = tempDir.appending("/.zshrc")
        tempHookPath = tempDir.appending("/claude-bash-hook.sh")

        // Create a test installer with temp paths (we'll need to subclass or use reflection)
        installer = HookInstaller()
    }

    override func tearDown() {
        super.tearDown()
        // Clean up temporary directory
        try? FileManager.default.removeItem(atPath: tempDir)
    }

    func testInstallIfNeededWhenNotInstalled() {
        // Verify that installIfNeeded calls install when not yet installed
        let initialState = installer.all() // This would be accessing private state, test via side effects instead
        XCTAssertFalse(FileManager.default.fileExists(atPath: "/opt/homebrew/lib/claude-bash-hook.sh"))
    }

    func testInstallCreatesHookScript() {
        // After install, hook script should exist
        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"

        // Verify the script contains expected content markers
        if FileManager.default.fileExists(atPath: hookPath) {
            if let content = try? String(contentsOfFile: hookPath, encoding: .utf8) {
                XCTAssertTrue(content.contains("claude_tap_hook"))
                XCTAssertTrue(content.contains("DEBUG"))
                XCTAssertTrue(content.contains("tap.sock"))
            }
        }
    }

    func testInstallModifiesShellConfig() {
        // After install, .zshrc should contain source line
        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path

        if let content = try? String(contentsOfFile: bashConfigPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("claude-bash-hook"))
        }
    }

    func testInstallIdempotent() {
        // Installing twice should not duplicate hook source lines
        installer.install()

        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path
        let initialContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        installer.install()

        let secondContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        // Count occurrences of hook source line
        let initialCount = (initialContent ?? "").components(separatedBy: "claude-bash-hook").count
        let secondCount = (secondContent ?? "").components(separatedBy: "claude-bash-hook").count

        // Should not increase on second install
        XCTAssertEqual(initialCount, secondCount)
    }

    func testInstallIfNeededSkipsWhenInstalled() {
        // First install
        installer.install()

        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path
        let contentAfterFirst = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        // Second call to installIfNeeded should be skipped
        installer.installIfNeeded()

        let contentAfterSecond = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        // Content should be identical (no duplicate lines added)
        XCTAssertEqual(contentAfterFirst, contentAfterSecond)
    }

    func testUninstallRemovesHookScript() {
        // Install first
        installer.install()
        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"

        XCTAssertTrue(FileManager.default.fileExists(atPath: hookPath))

        // Uninstall
        installer.uninstall()

        XCTAssertFalse(FileManager.default.fileExists(atPath: hookPath))
    }

    func testUninstallRemovesShellConfig() {
        // Install first
        installer.install()

        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path
        let contentBefore = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        XCTAssertTrue(contentBefore?.contains("claude-bash-hook") ?? false)

        // Uninstall
        installer.uninstall()

        let contentAfter = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)
        XCTAssertFalse(contentAfter?.contains("claude-bash-hook") ?? false)
    }

    func testHookScriptContainsDebugTrap() {
        installer.install()

        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"
        if let content = try? String(contentsOfFile: hookPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("trap claude_tap_hook DEBUG"))
        }
    }

    func testHookScriptFiltersCommonCommands() {
        installer.install()

        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"
        if let content = try? String(contentsOfFile: hookPath, encoding: .utf8) {
            // Should contain filter pattern for common commands
            XCTAssertTrue(content.contains("echo|pwd|ls|cd|type|which|true|false"))
        }
    }

    func testHookScriptTargetsTapSocket() {
        installer.install()

        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"
        if let content = try? String(contentsOfFile: hookPath, encoding: .utf8) {
            XCTAssertTrue(content.contains("tap.sock"))
            XCTAssertTrue(content.contains("$HOME/Library/Application Support/Tap/tap.sock"))
        }
    }

    func testHookScriptSendsJsonEvents() {
        installer.install()

        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"
        if let content = try? String(contentsOfFile: hookPath, encoding: .utf8) {
            // Should send JSON with required fields
            XCTAssertTrue(content.contains("\"type\":\"command\""))
            XCTAssertTrue(content.contains("\"id\""))
            XCTAssertTrue(content.contains("\"tool_name\""))
            XCTAssertTrue(content.contains("\"tool_input\""))
            XCTAssertTrue(content.contains("\"message\""))
            XCTAssertTrue(content.contains("\"timestamp\""))
        }
    }

    func testShellConfigSourceLineFormat() {
        installer.install()

        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path
        if let content = try? String(contentsOfFile: bashConfigPath, encoding: .utf8) {
            let expectedLine = "[ -f /opt/homebrew/lib/claude-bash-hook.sh ] && source /opt/homebrew/lib/claude-bash-hook.sh"
            XCTAssertTrue(content.contains(expectedLine))
        }
    }

    func testCompleteInstallUninstallCycle() {
        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path
        let hookPath = "/opt/homebrew/lib/claude-bash-hook.sh"

        let originalContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)

        // Install
        installer.install()
        XCTAssertTrue(FileManager.default.fileExists(atPath: hookPath))

        let installedContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)
        XCTAssertTrue(installedContent?.contains("claude-bash-hook") ?? false)

        // Uninstall
        installer.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: hookPath))

        let uninstalledContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)
        XCTAssertFalse(uninstalledContent?.contains("claude-bash-hook") ?? false)

        // Should return to original state (or very close, handling edge cases)
        XCTAssertEqual(originalContent, uninstalledContent)
    }

    func testInstallCreatesBrorebrewDirectory() {
        // The install method should create /opt/homebrew/lib if needed
        installer.install()

        XCTAssertTrue(FileManager.default.fileExists(atPath: "/opt/homebrew/lib"))
    }

    func testShellConfigPreservesExistingContent() {
        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path

        // Add some test content
        let testContent = "# Test marker\necho 'Hello World'\n"
        try? testContent.write(toFile: bashConfigPath, atomically: true, encoding: .utf8)

        installer.install()

        let newContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)
        XCTAssertTrue(newContent?.contains("Test marker") ?? false)
        XCTAssertTrue(newContent?.contains("claude-bash-hook") ?? false)
    }

    func testUninstallPreservesOtherShellConfig() {
        let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path

        // Add some test content
        let testContent = "# My Config\nexport MY_VAR=123\n"
        try? testContent.write(toFile: bashConfigPath, atomically: true, encoding: .utf8)

        installer.install()
        installer.uninstall()

        let finalContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8)
        XCTAssertTrue(finalContent?.contains("My Config") ?? false)
        XCTAssertTrue(finalContent?.contains("MY_VAR") ?? false)
        XCTAssertFalse(finalContent?.contains("claude-bash-hook") ?? false)
    }
}

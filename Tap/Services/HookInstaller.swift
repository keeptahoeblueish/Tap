import Foundation

final class HookInstaller {
    private let fileManager = FileManager.default
    private let bashHookPath = "/opt/homebrew/lib/claude-bash-hook.sh"
    private let bashConfigPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".zshrc").path

    func installIfNeeded() {
        // Check if hooks are already installed
        if isInstalled() {
            return
        }
        install()
    }

    func install() {
        // Create bash hook script if it doesn't exist
        createBashHook()

        // Add hooks to shell configuration
        addHooksToShellConfig()
    }

    func uninstall() {
        // Remove hooks from shell configuration
        removeHooksFromShellConfig()

        // Clean up hook script file
        try? fileManager.removeItem(atPath: bashHookPath)
    }

    // MARK: - Private

    private func isInstalled() -> Bool {
        // Check if bash hook script exists
        guard fileManager.fileExists(atPath: bashHookPath) else {
            return false
        }

        // Check if hooks are sourced in shell config
        guard let bashConfig = try? String(contentsOfFile: bashConfigPath, encoding: .utf8) else {
            return false
        }

        return bashConfig.contains("claude-bash-hook")
    }

    private func createBashHook() {
        let hookScript = """
        # Claude Bash Hook for Tap
        # This hook sends bash commands to the Tap socket for permission requests

        claude_tap_hook() {
            # Get the command that's about to be executed
            local cmd="$BASH_COMMAND"

            # Skip certain commands to avoid noise
            if [[ "$cmd" =~ ^(echo|pwd|ls|cd|type|which|true|false)\\s* ]]; then
                return 0
            fi

            # Get the socket path from Tap app
            local socket_path="$HOME/Library/Application Support/Tap/tap.sock"

            # Only send if socket exists
            if [[ -S "$socket_path" ]]; then
                # Send command event to Tap
                {
                    echo "{\"type\":\"command\",\"id\":\"bash_$(date +%s%N)\",\"tool_name\":\"Bash\",\"tool_input\":\"$cmd\",\"message\":\"Claude wants to run: $cmd\",\"timestamp\":$(date +%s)}"
                } 2>/dev/null | nc -U "$socket_path" 2>/dev/null || true
            fi

            return 0
        }

        # Install the hook
        if [[ -z "$(shopt -s | grep -F 'extdebug')" ]]; then
            shopt -s extdebug
            trap claude_tap_hook DEBUG
        fi
        """

        // Create Homebrew lib directory if needed
        try? fileManager.createDirectory(atPath: "/opt/homebrew/lib", withIntermediateDirectories: true)

        // Write hook script
        do {
            try hookScript.write(toFile: bashHookPath, atomically: true, encoding: .utf8)
            // Make it readable
            try fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: bashHookPath)
        } catch {
            print("HookInstaller: Failed to create bash hook: \(error.localizedDescription)")
        }
    }

    private func addHooksToShellConfig() {
        // Read current config
        var configContent = (try? String(contentsOfFile: bashConfigPath, encoding: .utf8)) ?? ""

        // Add source line if not already present
        let sourceLine = "[ -f /opt/homebrew/lib/claude-bash-hook.sh ] && source /opt/homebrew/lib/claude-bash-hook.sh"
        if !configContent.contains("claude-bash-hook") {
            // Add to end of file with newline
            if !configContent.isEmpty && !configContent.hasSuffix("\n") {
                configContent += "\n"
            }
            configContent += "\n# Claude Tap Hooks\n\(sourceLine)\n"

            // Write back
            do {
                try configContent.write(toFile: bashConfigPath, atomically: true, encoding: .utf8)
            } catch {
                print("HookInstaller: Failed to update shell config: \(error.localizedDescription)")
            }
        }
    }

    private func removeHooksFromShellConfig() {
        // Read current config
        guard let configContent = try? String(contentsOfFile: bashConfigPath, encoding: .utf8) else {
            return
        }

        // Remove hook source lines
        let lines = configContent.split(separator: "\n", omittingEmptySubsequences: false)
        let filteredLines = lines.filter { !$0.contains("claude-bash-hook") && !$0.contains("Claude Tap Hooks") }

        // Write back
        let updatedContent = filteredLines.joined(separator: "\n")
        do {
            try updatedContent.write(toFile: bashConfigPath, atomically: true, encoding: .utf8)
        } catch {
            print("HookInstaller: Failed to remove from shell config: \(error.localizedDescription)")
        }
    }
}

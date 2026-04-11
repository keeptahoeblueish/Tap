import Foundation

final class HookInstaller {
    let settingsPath: String
    let hookScriptPath: String

    private static let tapHookMarker = "tap-hook"

    init(settingsPath: String? = nil, hookScriptPath: String? = nil) {
        self.settingsPath = settingsPath ?? {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return home.appendingPathComponent(".claude/settings.json").path
        }()
        self.hookScriptPath = hookScriptPath ?? {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return supportDir.appendingPathComponent("Tap/tap-hook.sh").path
        }()
    }

    func installIfNeeded() {
        guard !isInstalled() else { return }
        install()
    }

    func isInstalled() -> Bool {
        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let content = String(data: data, encoding: .utf8) else {
            return false
        }
        return content.contains(Self.tapHookMarker)
    }

    func install() {
        installHookScript()
        installHookConfig()
    }

    private func installHookScript() {
        let dir = (hookScriptPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let script = generateHookScript()
        try? script.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hookScriptPath)
    }

    private func installHookConfig() {
        var settings: [String: Any] = [:]

        if FileManager.default.fileExists(atPath: settingsPath),
           let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Add PreToolUse hook for permission requests
        var preToolUse = hooks["PreToolUse"] as? [[String: Any]] ?? []
        if !containsTapHook(preToolUse) {
            preToolUse.append([
                "matcher": "*",
                "hooks": [[
                    "type": "command",
                    "command": "TAP_EVENT_TYPE=permission \(hookScriptPath)",
                    "timeout": 310000,
                    "description": Self.tapHookMarker
                ]]
            ])
        }

        // Add Stop hook for task completion
        var stop = hooks["Stop"] as? [[String: Any]] ?? []
        if !containsTapHook(stop) {
            stop.append([
                "hooks": [[
                    "type": "command",
                    "command": "TAP_EVENT_TYPE=complete \(hookScriptPath)",
                    "timeout": 5000,
                    "description": Self.tapHookMarker
                ]]
            ])
        }

        // Add Notification hook for errors/blockers
        var notification = hooks["Notification"] as? [[String: Any]] ?? []
        if !containsTapHook(notification) {
            notification.append([
                "matcher": "*",
                "hooks": [[
                    "type": "command",
                    "command": "TAP_EVENT_TYPE=blocker \(hookScriptPath)",
                    "timeout": 5000,
                    "description": Self.tapHookMarker
                ]]
            ])
        }

        hooks["PreToolUse"] = preToolUse
        hooks["Stop"] = stop
        hooks["Notification"] = notification
        settings["hooks"] = hooks

        let dir = (settingsPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func isTapHookEntry(_ hookDef: [String: Any]) -> Bool {
        if let desc = hookDef["description"] as? String, desc.contains(Self.tapHookMarker) { return true }
        if let cmd = hookDef["command"] as? String, cmd.contains(Self.tapHookMarker) { return true }
        return false
    }

    private func containsTapHook(_ entries: [[String: Any]]) -> Bool {
        entries.contains { entry in
            let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
            return innerHooks.contains { isTapHookEntry($0) }
        }
    }

    func uninstall() {
        try? FileManager.default.removeItem(atPath: hookScriptPath)

        guard FileManager.default.fileExists(atPath: settingsPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              var settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var hooks = settings["hooks"] as? [String: Any] else { return }

        for key in hooks.keys {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entry in
                    let innerHooks = entry["hooks"] as? [[String: Any]] ?? []
                    return innerHooks.contains { isTapHookEntry($0) }
                }
                hooks[key] = entries.isEmpty ? nil : entries
            }
        }

        settings["hooks"] = hooks
        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: settingsPath))
        }
    }

    private func generateHookScript() -> String {
        let socketPath = {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return supportDir.appendingPathComponent("Tap/tap.sock").path
        }()

        let configPath = {
            let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return supportDir.appendingPathComponent("Tap/config").path
        }()

        return """
        #!/bin/bash
        # tap-hook — Claude Code hook for Tap notifications
        # Auto-installed by Tap.app. Do not edit manually.

        SOCKET_PATH="\(socketPath)"
        CONFIG_PATH="\(configPath)"
        EVENT_TYPE="${TAP_EVENT_TYPE:-notification}"

        # Load ntfy topic if configured
        NTFY_TOPIC=""
        [ -f "$CONFIG_PATH" ] && NTFY_TOPIC=$(grep "^ntfy_topic=" "$CONFIG_PATH" 2>/dev/null | cut -d= -f2)

        # Send to ntfy (phone notifications)
        send_ntfy() {
            local title="$1" message="$2" priority="$3" tags="$4"
            [ -z "$NTFY_TOPIC" ] && return
            curl -s -o /dev/null \\
                -H "Title: $title" \\
                -H "Priority: $priority" \\
                -H "Tags: $tags" \\
                -d "$message" \\
                "https://ntfy.sh/$NTFY_TOPIC" &
        }

        # If Tap isn't running, still try ntfy, then fall through
        if [ ! -S "$SOCKET_PATH" ]; then
            if [ "$EVENT_TYPE" = "permission" ]; then
                INPUT=$(cat)
                TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
                send_ntfy "Permission Needed" "Claude wants to run: $TOOL_NAME" "urgent" "warning"
                echo '{"decision": "ask"}'
            fi
            exit 0
        fi

        INPUT=$(cat)
        EVENT_ID="evt_$(date +%s)_$$"

        case "$EVENT_TYPE" in
            permission)
                TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")
                TOOL_INPUT=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); i=d.get('tool_input',{}); print(i if isinstance(i,str) else json.dumps(i)[:100])" 2>/dev/null || echo "")
                MESSAGE="Claude wants to run: ${TOOL_NAME}${TOOL_INPUT:+ ($TOOL_INPUT)}"
                send_ntfy "Permission Needed" "$MESSAGE" "urgent" "warning"
                RESPONSE=$(echo "{\\"type\\":\\"permission\\",\\"id\\":\\"$EVENT_ID\\",\\"tool_name\\":\\"$TOOL_NAME\\",\\"tool_input\\":\\"$TOOL_INPUT\\",\\"message\\":\\"$MESSAGE\\",\\"timestamp\\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null)
                [ -z "$RESPONSE" ] && echo '{"decision": "ask"}' || echo "$RESPONSE"
                ;;
            complete)
                send_ntfy "Task Complete" "Claude finished the task" "default" "white_check_mark"
                echo "{\\"type\\":\\"complete\\",\\"id\\":\\"$EVENT_ID\\",\\"message\\":\\"Task complete\\",\\"timestamp\\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
                ;;
            error)
                ERROR_MSG=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_result','Error occurred')[:200])" 2>/dev/null || echo "An error occurred")
                send_ntfy "Error" "$ERROR_MSG" "high" "x"
                echo "{\\"type\\":\\"error\\",\\"id\\":\\"$EVENT_ID\\",\\"message\\":\\"$ERROR_MSG\\",\\"timestamp\\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
                ;;
            blocker)
                send_ntfy "Action Needed" "Claude needs manual action from you" "urgent" "raised_hand"
                echo "{\\"type\\":\\"blocker\\",\\"id\\":\\"$EVENT_ID\\",\\"message\\":\\"Claude needs manual action from you\\",\\"timestamp\\":$(date +%s)}" | socat - UNIX-CONNECT:"$SOCKET_PATH" 2>/dev/null &
                ;;
        esac
        exit 0
        """
    }
}

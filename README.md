# Tap - Claude Command Notification System

Tap is a macOS notification system that allows Claude AI to request permissions for commands before execution. It provides a secure bridge between Claude's operations and your system through a menu bar app that displays pending actions and allows you to approve or deny requests.

## Features

- **Permission Requests**: Claude can request permission before running sensitive commands like git push, file deletion, or deployment operations
- **Real-time Notifications**: Receive macOS notifications for important events (blockers, errors, task completions)
- **Menu Bar Integration**: Lightweight menu bar app shows all pending events at a glance
- **Bash Hook System**: Automatic bash command interception via DEBUG trap hooks
- **Unix Domain Socket IPC**: Efficient inter-process communication between Claude CLI and the Tap app
- **Approval/Denial**: Quick approve/deny buttons for permission requests
- **Event History**: View recent events and their status in the menu bar

## Architecture

Tap consists of five main components:

### 1. Socket Server (`SocketServer.swift`)
- Listens on Unix domain socket at `~/Library/Application Support/Tap/tap.sock`
- Receives command events as newline-delimited JSON
- Handles blocking for permission requests (up to 5-minute timeout)
- Routes events to the app state and sends responses back to Claude

### 2. Notification Manager (`NotificationManager.swift`)
- Creates and sends macOS notifications to the user
- Defines notification categories: PERMISSION (approve/deny), INFO (informational)
- Handles notification responses and routes them to the app state
- Integrates with UserNotifications framework

### 3. Event Store (`EventStore.swift`)
- In-memory store for recent events (max 50)
- Tracks event status: pending, approved, denied, dismissed
- Notifies observers when events change via closure callbacks

### 4. Hook Installer (`HookInstaller.swift`)
- Installs bash DEBUG trap hook on first launch
- Integrates with `.zshrc` shell configuration for persistence
- Filters common navigation commands (echo, pwd, ls, cd, etc.)
- Sends intercepted commands as JSON events to the socket
- Provides idempotent install/uninstall operations

### 5. UI Layer (`TapApp.swift`, `MenuBarView.swift`)
- SwiftUI-based menu bar application
- Displays socket connection status
- Shows list of recent events with color coding
- Provides approve/deny buttons for permission requests
- Shows "Reinstall Hooks" and "Quit Tap" buttons

## Event Types

Events sent through Tap can be one of four types:

| Type | Color | Purpose |
|------|-------|---------|
| `permission` | Orange | Requests user approval for a sensitive operation |
| `blocker` | Blue | Indicates a blocking issue that needs immediate attention |
| `complete` | Green | Notifies that a task has completed successfully |
| `error` | Red | Reports an error or failure |

## Installation

### Prerequisites
- macOS 14.0 or later
- Swift 5.9 or later
- Homebrew (for the bash hook installation path)

### Building from Source

```bash
swift build
```

### Running

```bash
# Run the app in the background
.build/debug/Tap &

# Or install as a menu bar app by running the binary directly
open .build/debug/Tap
```

## Hook Installation

When Tap launches, it automatically:

1. Creates a bash hook script at `/opt/homebrew/lib/claude-bash-hook.sh`
2. Adds a source line to `~/.zshrc` to load the hook on shell startup
3. Enables the bash DEBUG trap to intercept commands

The hook is idempotent—it's safe to run the installation multiple times.

To manually reinstall hooks, click the "Reinstall Hooks" button in the Tap menu bar.

## Event JSON Format

Commands sent from the bash hook to Tap follow this format:

```json
{
  "type": "command",
  "id": "bash_1234567890123456789",
  "tool_name": "Bash",
  "tool_input": "git push origin main",
  "message": "Claude wants to run: git push origin main",
  "timestamp": 1234567890
}
```

Permission request responses from Tap are:

```json
{
  "decision": "allow" | "deny"
}
```

## Socket Communication

Tap uses Unix domain sockets for inter-process communication:

- **Socket Path**: `~/Library/Application Support/Tap/tap.sock`
- **Protocol**: Newline-delimited JSON
- **Behavior**:
  - Permission events block until a response is sent (5-minute timeout)
  - Other events are processed asynchronously
  - The client receives the decision as a JSON response

## Testing

Run the test suite:

```bash
swift test
```

Tests cover:
- Notification category setup and content generation
- Socket server connection handling and event parsing
- Event store management and state transitions
- Hook installer idempotency and shell config integration
- Model encoding/decoding and computed properties

## Development

### Project Structure

```
Tap/
├── Tap/
│   ├── Models/
│   │   ├── TapEvent.swift      # Event model and status tracking
│   │   └── TapResponse.swift    # Response model
│   ├── Services/
│   │   ├── SocketServer.swift   # Unix socket server
│   │   ├── NotificationManager.swift  # macOS notifications
│   │   ├── EventStore.swift     # In-memory event storage
│   │   └── HookInstaller.swift  # Bash hook management
│   ├── MenuBarView.swift        # Menu bar UI
│   └── TapApp.swift             # App entry point and state
├── Tests/
│   ├── NotificationManagerTests.swift
│   ├── SocketServerTests.swift
│   ├── TapEventTests.swift
│   └── HookInstallerTests.swift
└── Package.swift                # Swift Package manifest
```

### Building with SPM

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test

# Run with verbose output
swift test -v
```

## Troubleshooting

### Hooks not working
- Check that `/opt/homebrew/lib/claude-bash-hook.sh` exists
- Verify the hook is sourced in your `.zshrc` file
- Look for the "Claude Tap Hooks" comment in `.zshrc`
- Try clicking "Reinstall Hooks" in the Tap menu bar

### Socket connection issues
- Ensure the app is running (check the menu bar)
- Verify the socket path: `ls -l ~/Library/Application\ Support/Tap/tap.sock`
- Check Console.app for error messages

### Notifications not appearing
- Verify Tap has notification permissions in System Preferences
- Check that macOS notifications are not disabled globally

## Uninstallation

To remove Tap:

1. Quit the app from the menu bar
2. Run: `swift run Tap uninstall` (future feature)
3. Or manually remove the hook from `~/.zshrc`
4. Delete the app bundle

## License

MIT

## Contributing

For bug reports and feature requests, please open an issue on GitHub.

# CLAUDE.md — Tap

## What Is Tap?

Open-source macOS menu bar app that sends native Apple notifications when Claude Code needs attention. Approve/deny from notifications (and eventually Apple Watch).

**Author:** Ryan Zaucha (keeptahoeblueish)
**License:** MIT
**Status:** Phase 1 (Mac app) — in development

## Architecture

- **Mac app** (Swift/SwiftUI) — MenuBarExtra, lives in menu bar
- **Hook script** (bash) — auto-installed into `~/.claude/settings.json`, sends events via Unix domain socket
- **Socket server** — listens at `~/Library/Application Support/Tap/tap.sock`
- **Notifications** — UserNotifications framework with PERMISSION (approve/deny) and INFO categories

Flow: Claude Code → PreToolUse hook → tap-hook.sh → socket → Tap.app → macOS notification → user action → response back through socket → hook returns decision → Claude Code continues

## Tech Stack

- Swift 5.9+ / SwiftUI / macOS 14+
- Swift Package Manager (NOT Xcode project)
- UserNotifications framework
- Unix domain socket (Foundation)
- socat (brew dependency for hook script)

## Build & Run

```bash
swift build          # Build
swift test           # Run tests
swift run Tap        # Launch app
```

## Project Structure

```
Tap/
├── TapApp.swift              — @main, AppState, MenuBarExtra
├── MenuBarView.swift          — Dropdown UI
├── Models/
│   ├── TapEvent.swift         — Codable event with 4 types
│   └── TapResponse.swift      — Approve/deny response
└── Services/
    ├── SocketServer.swift     — Unix domain socket listener
    ├── NotificationManager.swift — macOS notifications + actions
    ├── HookInstaller.swift    — Auto-configures ~/.claude/settings.json
    └── EventStore.swift       — In-memory event history (max 50)
```

## Key Design Decisions

- **Zero config for users** — HookInstaller auto-writes to `~/.claude/settings.json` on first launch
- **Swift Package Manager** not Xcode project — simpler, CLI-buildable
- **Unix domain socket** not HTTP — local-only, no port conflicts, fast
- **PreToolUse hook blocks** until user responds (5 min timeout, then falls through to terminal)
- **Graceful degradation** — if Tap isn't running, hooks return `{"decision": "ask"}` and Claude Code prompts in terminal as normal

## Phases

- **Phase 1** (current): Mac menu bar app + macOS notifications
- **Phase 2**: Cloud relay (Express/TypeScript on Railway) for remote push
- **Phase 3**: iPhone + Apple Watch companion app (Expo React Native)

## This Is an Open Source Project

- Professional README matters — it's the front door
- MIT license
- Public repo: keeptahoeblueish/Tap (not created yet)

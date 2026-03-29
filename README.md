# Tap

[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)](https://www.apple.com/macos/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)](https://swift.org)
[![MIT License](https://img.shields.io/badge/License-MIT-green)](LICENSE)
[![Phase: Mac App](https://img.shields.io/badge/Phase-Mac%20App-blue)](#roadmap)

Native macOS menu bar app that sends notifications when Claude Code needs your attention. Get out of the terminal and back to work.

## The Problem

Claude Code users face a choice:
1. Babysit the terminal pressing Y/N all day
2. Turn on bypass mode and hope for the best

Tap creates a third option: **walk away and get notified when Claude actually needs you**.

## What It Does

1. **One-click setup** — Install Tap, launch it. That's it. No config files, no terminal commands.
2. **Auto-configures Claude Code** — On first launch, Tap adds three hooks to `~/.claude/settings.json`
3. **Native notifications** — When Claude Code needs permission, hits an error, finishes a task, or needs manual action, you get a macOS notification
4. **Approve/Deny buttons** — Permission requests come with action buttons. Your decision flows back to Claude Code instantly
5. **View history** — Click the menu bar icon to see recent events at a glance

## How It Works

```
Claude Code
    ↓
Hits hook (permission request)
    ↓
tap-hook.sh fires
    ↓
Sends JSON → Unix socket → Tap.app
    ↓
Native macOS notification with Approve/Deny
    ↓
User clicks Approve
    ↓
Response → socket → Claude Code continues
```

Three hooks are auto-installed to `~/.claude/settings.json`:
- **PreToolUse** — fires before Claude runs a tool, blocks until you approve/deny
- **Stop** — fires when a task completes, shows a completion notification
- **Notification** — fires for errors, blockers, or other alerts

No `.zshrc` modifications. No bash traps. Just sockets and notifications.

## Notification Types

| Type | Example | Actions |
|------|---------|---------|
| **Permission** | "Claude wants to run: git push origin main" | Approve / Deny |
| **Blocker** | "Claude needs you to log in to Railway" | Dismiss |
| **Complete** | "Deployed to preview — took 12 minutes" | Dismiss |
| **Error** | "Build failed: TypeScript error" | Dismiss |

## Requirements

- **macOS 14 (Sonoma)** or later
- **Claude Code CLI** installed
- **socat** — `brew install socat` (used by the hook script for socket communication)

## Install

### From Releases
1. Download `Tap.app` from [Releases](../../releases)
2. Drag to **Applications**
3. Launch — Tap auto-configures Claude Code on first run

### From Homebrew
```bash
brew install --cask tap
```

## What Gets Modified

On first launch, Tap adds three hooks to `~/.claude/settings.json`. Your existing settings are preserved. If hooks get removed, click "Reinstall Hooks" in the menu bar. Uninstall from the app menu to cleanly remove all hooks.

## Tech Stack

- **Swift** / **SwiftUI** / **MenuBarExtra** (macOS 14+)
- **UserNotifications** framework for native alerts
- **Unix domain sockets** for IPC between Claude Code and Tap
- **socat** in the hook script to communicate with sockets

## Project Structure

```
Tap/
├── Tap/
│   ├── TapApp.swift              — App entry point, MenuBarExtra
│   ├── MenuBarView.swift         — Menu bar dropdown UI
│   ├── Models/
│   │   ├── TapEvent.swift        — Event types and JSON parsing
│   │   └── TapResponse.swift     — Approve/deny response
│   └── Services/
│       ├── SocketServer.swift    — Unix domain socket listener
│       ├── NotificationManager.swift — macOS notifications
│       ├── HookInstaller.swift   — Auto-configures Claude Code
│       └── EventStore.swift      — Recent event history
├── Scripts/
│   └── tap-hook.sh               — Hook script (auto-installed)
├── Tests/                        — Test suite
└── Distribution/
    └── tap.rb                    — Homebrew cask formula
```

## Event Flow

When Claude Code triggers a hook:
1. `tap-hook.sh` serializes the request as JSON
2. Sends it through a Unix domain socket to Tap
3. Tap.app displays a native macOS notification
4. User clicks Approve or Deny
5. Response flows back through the socket to Claude Code
6. Claude Code reads the response and continues or stops

Blocking (permission requests) has a 5-minute timeout.

## Roadmap

- **Phase 1** (current): Mac menu bar app with native notifications ✅
- **Phase 2**: Cloud relay server for remote push notifications
- **Phase 3**: iPhone + Apple Watch companion app — approve requests from your wrist

## License

MIT

## Author

Ryan Zaucha ([@keeptahoeblueish](https://github.com/keeptahoeblueish))

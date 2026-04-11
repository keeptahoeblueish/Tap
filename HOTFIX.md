# HOTFIX.md — Tap

## When a hotfix is justified

A hotfix skips the preview-build-and-stakeholder-review cycle and goes straight to a tagged release. Only use it for:

- **Crash on launch** — Tap opens, then immediately quits.
- **Claude Code integration broken** — the hook script can't reach the socket, so Claude Code blocks forever waiting for a response Tap can't send.
- **Data loss** — Tap corrupts `~/Library/Application Support/Tap/` in a way that loses user settings.
- **Security vulnerability** — Tap's socket is accessible to other users or unprivileged processes on the machine, or a dependency has a CVE.
- **Notification permission loss** — Tap stops being able to show notifications after a macOS update.

Do NOT hotfix for: a visual bug, a menu bar icon issue, a single user's keychain weirdness, or an unreproducible crash.

## Procedure

1. **Confirm the incident is a hotfix class.** If users can live with it for 24 hours, it's not a hotfix.
2. **Create a fix commit on `main`.** Minimal change only — just the lines needed to fix. Revert commits are acceptable and often the right move.
3. **Bump the patch version** in `Package.swift` (or wherever the version constant lives) and the Sparkle appcast entry.
4. **Build locally:**
   ```
   swift build -c release
   ```
   Sanity-check the built `.build/release/Tap` runs and exhibits the fix.
5. **Codesign and notarize:**
   ```
   codesign --deep --force --timestamp --options runtime --sign "Developer ID Application: <Ryan>" .build/release/Tap
   xcrun notarytool submit Tap.zip --keychain-profile <profile> --wait
   xcrun stapler staple Tap.app
   ```
6. **Cut a git tag:**
   ```
   git tag -a vX.Y.Z -m "Hotfix: <one-line description>"
   git push origin main --tags
   ```
7. **Create the GitHub Release** with the notarized `.app` (or `.dmg`) attached. Tag release notes should start with "HOTFIX:" so installed clients reading the changelog know this was an emergency push.
8. **Update the Sparkle appcast XML** (if wired) to point at the new release. Users with Sparkle auto-update will pick up the hotfix on their next poll interval.
9. **File a post-incident note** in the repo (or in `~/.claude/projects/-Users-betterclaw/memory/`) describing what broke, why the normal cycle was skipped, and any follow-up work needed to prevent recurrence.

## What to watch for after the hotfix ships

- **Crash reports in `~/Library/Logs/DiagnosticReports/Tap*`** on the Mac Mini and any test machines.
- **Issues filed on `keeptahoeblueish/Tap`** in the first 48 hours — hotfixes can introduce new regressions because they skip the preview cycle.
- **Socket connectivity** — tail Claude Code hook logs to confirm `tap-hook.sh` is still getting responses.

## What is NOT a Tap hotfix

- **Bugs in Claude Code itself** — file upstream at `github.com/anthropics/claude-code`. Not your hotfix.
- **Bugs in the hook script's installation logic** — these are config bugs, not Tap binary bugs. Fix in the installer, ship as a normal release.
- **Feature additions disguised as fixes** — if it adds new functionality, it's not a hotfix.

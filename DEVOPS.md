# DEVOPS.md — Tap

## What this is

Tap is an open-source (MIT) macOS menu bar app that notifies the user when Claude Code needs attention. Written in Swift with Swift Package Manager. There is **no cloud infrastructure** — Tap is a native macOS binary that ships via GitHub Releases and runs on the user's own Mac. Items 1–19 of the portfolio pipeline completeness checklist are N/A here.

## How "environments" map to Tap

Tap doesn't have dev/preview/production Railway envs. It has:

1. **development** — whatever you build with `swift build` / `swift run Tap` on the Mac Mini. Lives in `.build/`. Never shipped.
2. **preview** — a signed, notarized `.app` built locally via the release script and shared with a small group for hands-on testing before cutting a tag. This is equivalent to a TestFlight build — it's what Ryan approves before a public release.
3. **production** — a tagged GitHub Release with the signed/notarized `.app` (and optional `.pkg` installer) attached, downloadable by the public. Sparkle auto-update (when wired) points the installed base at the latest tagged release.

## Ship flow

1. Work on `main`. Swift tests run on every push via `.github/workflows/build.yml`.
2. Run `swift test` locally and confirm green before tagging.
3. **Preview:** build the signed `.app` via `Scripts/release.sh` (or equivalent), codesign with Ryan's Developer ID Application certificate, notarize with `xcrun notarytool`, staple with `xcrun stapler staple`, and share the `.app` with stakeholders.
4. **Production:** on green light, cut a git tag `git tag v<semver> && git push --tags`. GitHub Actions (or manual) builds the signed/notarized release asset and attaches it to the GitHub Release page.
5. If Sparkle is wired, update the appcast XML with the new version, signature, and changelog so installed clients auto-update.

## Code signing & notarization

- **Developer ID Application certificate** — Ryan's Apple Developer account. Required for notarization. Distributed via Apple's Developer ID program, not the Mac App Store.
- **Notarization** — `xcrun notarytool submit --apple-id <ryan> --team-id <team> --keychain-profile <profile>`. The `AuthKey_UG6Q5968M7.p8` at `~/.appstoreconnect/AuthKey_UG6Q5968M7.p8` is the App Store Connect API key used for notarization.
- **Gatekeeper** — a notarized Developer ID binary opens on macOS without the "unidentified developer" warning. Tap MUST be notarized before every public release.

## Secrets

- Apple Developer ID certificate (stored in Ryan's login keychain on the Mac Mini).
- App Store Connect API key at `~/.appstoreconnect/AuthKey_UG6Q5968M7.p8` — used for notarization.
- No database credentials. No third-party API keys. No webhook secrets.

## What is intentionally not here

- **No Railway.** No server to deploy.
- **No Neon.** No database.
- **No `/api/version` / `/api/healthz` / CORS / CSP.** Native macOS app.
- **No `promote.sh` / `rollback.sh`.** The ship mechanism is `git tag` + GitHub Release, not a multi-branch Railway ladder.
- **No branch protection on preview/production.** Tap uses `main` as its only long-lived branch; releases are pinned by git tag, not by branch.

## Rollback

Releases are immutable by tag. To roll back:

1. Mark the bad GitHub Release as "Pre-release" so Sparkle ignores it (or delete the release binary).
2. Point the Sparkle appcast back at the previous release version.
3. Users on auto-update will pick up the previous release the next time Sparkle polls; users who manually installed the bad version need to download the previous release themselves.

For a truly bad release (crash-on-launch, data loss, security), see `HOTFIX.md`.

## Health

No server-side health check. Health = crash reports in `~/Library/Logs/DiagnosticReports/` on user machines. Consider wiring Sentry for Swift if crashes become common.

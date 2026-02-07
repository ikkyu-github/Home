# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

### Repo hygiene
- Added/extended `.gitignore` patterns to prevent common build artifacts and macOS metadata from re-entering the repo.
- Added `Dev/Tools/Scripts/clean_repo.sh` (idempotent) to remove:
  - `RuntimePackages/**/.build/`
  - `build_logs/`
  - `**/__MACOSX/`
  - `**/.DS_Store`
  - `**/xcuserdata/`

### Architecture: App ↔ Core layering
- Removed direct `BrowserCore` imports from the App target and routed app-facing creation/wiring through `SafariLikeKit`.
- Introduced `SafariLikeAppFacade` in `SafariLikeKit` as the app-facing entrypoint for per-window session creation and lifecycle teardown.
- Re-exported the minimal needed type(s) (e.g. `DownloadCenter`) through `SafariLikeKit` so App code stays core-module import-free.

### Sessions: SSOT + duplicate-creation diagnostics
- Added an internal process-wide `BrowserSceneSessionRegistry` (weakly held) in `SafariLikeKit` to enforce a single live `BrowserSceneSession` per `windowID`.
- Updated `SafariLikeFactory.makeSceneSession(sceneID:windowID:...)` to reuse the existing session for that `windowID` (and optionally trigger restore) instead of creating duplicates.
- Updated the app facade and internal providers to consult/register with the shared registry; in `DEBUG`, duplicate creations are logged and the extra instance is invalidated.

### Remaining work (tracked)
- Tighten deterministic wiring order beyond session creation (as needed) by centralizing any remaining runtime registrations behind the facade/factory.
- Centralize WebKit autoplay/media policy defaults + add targeted debug logging for audio/autoplay stability.

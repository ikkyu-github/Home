# Fix: Multiple commands produce *.stringsdata (SafariLikeKit)

Date: 2026-01-22

## Root cause
SafariLikeKit is built from a `PBXFileSystemSynchronizedRootGroup` (folder-based target membership).
Duplicate Swift basenames under `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/` caused Xcode to generate colliding derived outputs (e.g. `BrowserSceneSession.stringsdata`, `ChromePolicy+UIKit.stringsdata`).

## What changed
### Kept (single canonical copies)
- `Core/Session/BrowserSceneSession.swift`
- `Core/Session/BrowserSceneSession+Lifecycle.swift`

### Removed duplicates / placeholders (to eliminate basename collisions)
- Removed duplicate copies of:
  - `BrowserSceneSession.swift`
  - `BrowserSceneSession+Lifecycle.swift`
  - `ChromePolicy+UIKit.swift`
  - `UIState.swift` (duplicate `BrowserUIStateImpl` definition)
- Removed placeholder stubs that only existed to avoid Xcode references:
  - `Runtime/TabManager.swift` (stub; real implementation is under `Runtime/TabManager/`)
  - `Plugins/Runtime/PluginEnablementStore.swift` (stub; real implementation is under `Plugins/Core/`)

### Layering cleanup (ChromePolicy)
- Added UIKit-free core protocol:
  - `Core/ChromePolicyTraits.swift`
- Added UIKit adapter (UI layer, but not named `+UIKit`):
  - `UI/ChromePolicyTraitCollectionAdapter.swift`

## Manual review
- UIKit lifecycle flush hooks were removed from SafariLikeKit’s lifecycle autosave wiring. The App / UI layer should ensure it calls `BrowserSceneSession.persistSessionNow()` during background/resign-active transitions.

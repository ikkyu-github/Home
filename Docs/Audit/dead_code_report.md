# Dead Code Report

Generated: 2026-02-03

## Update: 2026-02-09 “Dead/Unused Sweep” (evidence-backed)

### Safe to delete now
These are not referenced by the Xcode project file and are not under any SwiftPM target root, and the repo-wide search indicates no call sites.

#### Deleted in cleanup PR (2026-02-09)
- `App/UI/Debug/NavigationPolicyOverlayView.swift`
  - Evidence:
    - `rg -n "existing code from NavigationPolicyOverlayView.swift" --glob "**/*.swift" --glob "!App/UI/Debug/NavigationPolicyOverlayView.swift"` → 0 matches
    - `rg -n "NavigationPolicyOverlayView.swift" webOS.xcodeproj/project.pbxproj` → 0 matches
- `App/UI/Debug/NetworkDiagnosticsView.swift`
  - Evidence:
    - `rg -n "existing code from NetworkDiagnosticsView.swift" --glob "**/*.swift" --glob "!App/UI/Debug/NetworkDiagnosticsView.swift"` → 0 matches
    - `rg -n "NetworkDiagnosticsView.swift" webOS.xcodeproj/project.pbxproj` → 0 matches
- `App/UI/Debug/PerformanceOverlayView.swift`
  - Evidence:
    - `rg -n "existing code from PerformanceOverlayView.swift" --glob "**/*.swift" --glob "!App/UI/Debug/PerformanceOverlayView.swift"` → 0 matches
    - `rg -n "PerformanceOverlayView.swift" webOS.xcodeproj/project.pbxproj` → 0 matches
- `App/UI/Debug/RuntimeMetrics.swift`
  - Evidence:
    - `rg -n "existing code from RuntimeMetrics.swift" --glob "**/*.swift" --glob "!App/UI/Debug/RuntimeMetrics.swift"` → 0 matches
    - `rg -n "RuntimeMetrics.swift" webOS.xcodeproj/project.pbxproj` → 0 matches
- `App/UI/Debug/SafariLikeParityReport.swift`
  - Evidence:
    - `rg -n "existing code from SafariLikeParityReport.swift" --glob "**/*.swift" --glob "!App/UI/Debug/SafariLikeParityReport.swift"` → 0 matches
    - `rg -n "SafariLikeParityReport.swift" webOS.xcodeproj/project.pbxproj` → 0 matches
- `Dev/Tools/_legacy/LegacyPluginManagerImpl.swift`
  - Evidence:
    - `rg -n "PluginManagerImpl|BrowserPluginManager" --glob "**/*.swift" --glob "!Dev/Tools/_legacy/LegacyPluginManagerImpl.swift"` → 0 matches
    - `rg -n "LegacyPluginManagerImpl.swift" webOS.xcodeproj/project.pbxproj` → 0 matches

#### App debug stubs (placeholders)
- Files:
  - `App/UI/Debug/NavigationPolicyOverlayView.swift`
  - `App/UI/Debug/NetworkDiagnosticsView.swift`
  - `App/UI/Debug/PerformanceOverlayView.swift`
  - `App/UI/Debug/RuntimeMetrics.swift`
  - `App/UI/Debug/SafariLikeParityReport.swift`
- Evidence:
  - These files contain only a `#if DEBUG` wrapper + placeholder comment (`...existing code from ...`).
  - `webOS.xcodeproj/project.pbxproj` contains **no** references to these filenames (search: each basename; result: 0 matches).
  - Repo search for the placeholder marker finds **only** these 5 files (search regex: `\.\.\.existing code from`; result: 5 matches).
- Rationale:
  - The real implementations exist under `RuntimePackages/SafariLikeKit/.../Diagnostics/` (same basenames), so these app-level stubs are redundant.

#### Legacy plugin manager implementation (unused)
- File: `Dev/Tools/_legacy/LegacyPluginManagerImpl.swift`
- Evidence:
  - Project file has **no** reference to `LegacyPluginManagerImpl.swift` (0 matches).
  - Symbol search:
    - `PluginManagerImpl` appears only in this file (search: `\bPluginManagerImpl\b`; result: 1 match).
    - `BrowserPluginManager` appears only in this file (search: `\bBrowserPluginManager\b`; result: 2 matches including comment).

### Needs verification (delete or wire-in)

#### Dev diagnostics implementation (duplicate, not wired to build)
- File: `Dev/Diagnostics/Diagnostics.swift`
- Evidence:
  - Project file has **no** reference to `Dev/Diagnostics/Diagnostics.swift` (search: `Dev/Diagnostics/Diagnostics.swift`; result: 0 matches).
  - SwiftPM manifests have **no** reference to `Dev/Diagnostics`.
  - Canonical implementation exists in CoreKit:
    - `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Diagnostics/Diagnostics.swift`
- Action:
  - Safe to delete `Dev/Diagnostics/Diagnostics.swift` (it is not part of any target).

#### UI test sources not wired into the `webOSUITests` target
- Files:
  - `webOSUITests/RotationRegressionUITests.swift`
  - `webOSUITests/TabChromeUITests.swift`
- Evidence:
  - Xcode target + scheme exist (`xcodebuild -project webOS.xcodeproj -list` shows `webOSUITests`).
  - But `webOS.xcodeproj/project.pbxproj` has **no** reference to either Swift file (search: each filename; result: 0 matches), implying the target currently builds with no test sources.
  - Repo-wide symbol search:
    - `RotationRegressionUITests` appears in its file + inventory docs only.
    - `TabChromeUITests` appears only in its file.
- Decision fork:
  - If UITests are intended: add these files to the `webOSUITests` target membership (verify by running `xcodebuild -scheme webOSUITests test`).
  - If UITests are not intended: delete these files and consider removing the `webOSUITests` target/scheme.

### Symbols: likely unused (compiled) — needs verification

#### `AppSettingsStore`
- File: `App/AppSettingsStore.swift`
- Evidence:
  - Symbol search `\bAppSettingsStore\b` returns only the definition (1 match).
  - The app appears to use `AppSettings` as the settings authority.
- Verify:
  - Repo-wide search for `AppSettingsStore` remains 0 matches outside its definition.
  - Build `xcodebuild -scheme webOS build` (or the repo’s `xcodebuild` script task).

### Docs duplication
- Exact duplicates: none detected (hash-based scan across `**/*.md` yielded 0 duplicate groups).
- Conceptual duplication: see `Docs/Audit/duplication_report.md` for active duplication candidates.

## Scope & method (best-effort)
This report is a conservative sweep aimed at PR-safe cleanup:
- Grep-based usage search (no whole-program analysis)
- Xcode target membership check based on the repo’s folder-synchronized targets (most `Sources/**` and `Tests/**` files are compiled automatically unless explicitly excluded)
- Focus on obviously-unused files/symbols (zero references), drifted test files, and legacy shims

## Actions taken (completed)
- Removed the obsolete UI-owned render-budget path (`RenderPolicyManager`) and its drifting tests.
  - Rationale: render budgeting is already enforced by CoreKit `RenderBudgetPolicy` + runtime lifecycle (`TabLifecycleController`). Keeping a UI-owned budget authority was duplicate and side-effecty.

## High-confidence dead code candidates (0 references)
### `ChromeUIState`
- File: RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeUIState.swift
- Evidence: `ChromeUIState` is only referenced in its own file (no other matches in `RuntimePackages/**`).
- Suggested action: delete the file (or keep only if an upcoming UI layer still uses it). It is already marked deprecated.

## Drift / stale APIs (risk of future re-introduction)
### Render budget duplication (resolved)
- Previously:
  - UI lane code drove render state via `RenderPolicyManager.activate/deactivate`.
  - Tests referenced an older API (`activate(tabID:)`, `Decision.activeTabIDs`, `onDecisionChanged`) that did not exist.
- Now:
  - Only runtime code owns budgeting and attachment decisions.

## “Legacy shim” hotspots (not dead yet, but should be actively migrated)
These are not dead code today (they have references), but they are explicitly marked deprecated and represent consolidation opportunities.

### Scene session registry
- Files:
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/SceneSessionRegistry.swift
  - RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserWindowSession.swift
- Evidence: referenced by RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/AppGlue/AppWindowActions.swift
- Suggested action: once the app has fully moved to `sceneID`-based `BrowserSceneSession` via the factory, remove these.

## TODO/FIXME inventory (cleanup queue)
The following TODOs are present and can be used as a PR-safe “dead code / cleanup” checklist:
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Preview/Store+Preview.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Stores/DownloadStore.swift
- RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/NavigationService.swift
- RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift

## Notes
- A true unused-symbol report for Swift generally requires compiler indexing (e.g., Xcode index, `swiftc` frontend flags, or SourceKit tooling). This report intentionally avoids speculative deletions beyond the high-confidence cases above.

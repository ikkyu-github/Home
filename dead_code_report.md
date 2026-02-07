# Dead Code Report

Generated: 2026-02-03

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

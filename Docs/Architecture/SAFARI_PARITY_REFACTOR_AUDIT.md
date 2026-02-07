# Safari Parity Refactor Audit (WIP)

Generated: 2026-02-03

This document tracks a Safari-like architectural refactor with strict ownership and layering rules.

Primary goal: make ownership boundaries, lifecycle, and activation logic deterministic and Safari-like.

## Phase 1 — Dependency & Layer Audit

### Findings
- SwiftPM targets (observed):
  - Contracts: `SafariLikeContracts`
  - Core: `BrowserCore`, `SafariLikeCoreKit`, `SafariLikeUXKit`
  - UI: `SafariLikeKit`, `SafariLikeBuiltinPlugins`
  - Platform host: `SafariLikeUIKit`
- Declared graph matches observed imports (no cycles), but layering violations exist.

Reference artifacts:
- `build_logs/dependency_graph.md` (generated)
- `build_logs/dependency_graph.json` (generated)
- `Dev/Docs/Architecture/phase1_architecture_audit.md` (captured)

### Violations
1) UI imports Core directly
- `SafariLikeKit` (including `Sources/SafariLikeKit/UI/**` and ViewModel domains) imports `BrowserCore` and `SafariLikeCoreKit` broadly.
- This violates “UI must NEVER create or own WebKit or policy logic directly” and prevents dependency enforcement.

2) Platform host imports engine internals
- `SafariLikeUIKit` imports `SafariLikeCoreKit` (and depends on it as a SwiftPM dependency).

3) Plugin examples import Core
- `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Plugins/Examples/*` import `BrowserCore`.

4) Facade re-export leaks
- `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Reexports/BrowserCoreReexport.swift` uses `@_exported import BrowserCore`.
- `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/SafariLikeCoreKit.swift` uses `@_exported import BrowserCore`.

These re-exports undermine import-boundary auditing (call sites can use Core types without explicit import) and encourage UI-to-core coupling.

### Proposed Refactor Steps
- Split `SafariLikeKit` into explicit targets:
  - `SafariLikeUI` (SwiftUI views + view models): depends on `SafariLikeContracts` (+ `SafariLikeUXKit` if it stays Contracts-only).
  - `SafariLikeRuntimeGlue` (scene lifecycle, coordinators): depends on `SafariLikeCoreKit` and `SafariLikeContracts`.
  - Keep `SafariLikeKit` as a thin facade product that re-exports *only* stable Contracts (not BrowserCore/CoreKit).
- Move `Plugins/Examples/*` to depend only on `SafariLikeContracts` (and expose integration points via contracts).
- Remove `@_exported import BrowserCore` from `SafariLikeKit` and `SafariLikeCoreKit`.
  - Transition plan: add explicit imports where needed, then enforce with scripts.

## Phase 2 — Ownership Model Verification (initial pass)

### Ownership Map (current, partial)
App-scope (process-wide):
- `EngineController` (currently also owns per-tab `WebContext` map → NOT OK)
- `PolicyCenter.shared` (policy registry; potentially OK as App-scope if value-driven and stateless)
- `DownloadManager.shared` (allowed App-scope)

Scene-scope (per scene/window):
- `SceneRuntimeContext` (per `SceneID`)
- `SafariLikeCoreKit.TabRegistry` (per window/profile)
- `WebViewPool` (should be per scene/profile/pane, not global)
- `AttachmentCoordinator` (currently in `SafariLikeKit`, but functionally scene-scope)

Tab-scope (per tab):
- `TabWebStore` (single source of truth)
- `TabNavigationController`, `TabProcessRecoveryController`, `TabContentBlockingController`

### Violations / Risks Found
- `EngineController.shared` stores `activeContextByTabID` and `keyByTabID`.
  - This is tab-scope runtime state living at app-scope, and it crosses scene boundaries.
- `WebViewPool.shared` exists and is referenced as a default in CoreKit comments; pool also tracks process-wide pools via a static table.
  - Tab/WebView budgeting must be scene-scoped (Safari separation).
- `SceneRuntimeContext` contains WebView tiering + attach/detach decisions. This is correct *scope* (scene), but it currently lives in the UI package and imports `BrowserCore`/`SafariLikeCoreKit`.

### Proposed Refactor Steps
- Introduce an explicit `SceneEngineContext` (scene-scope) that owns:
  - an engine instance (or engine facade)
  - registries/pools
  - all observers/timers related to WebKit lifecycle
- Refactor `EngineController`:
  - keep it as an App-scope factory/event hub *without per-tab maps*, OR
  - make it scene-owned and injected into registries and stores.
- Remove global `WebViewPool.shared` in favor of scene-owned pools registered with `TabRegistry`.

## Phase 3 — TabWebStore Contract Hardening (checkpoint)

Status: TabWebStore contract surface has been restored to compile, but still requires an audit pass to ensure:
- no duplicated hidden state in extensions
- webview attachment is idempotent
- API surface matches the required list:
  - `WebViewPerformanceTier`
  - `performanceTier` getter/setter
  - `discardWebView()`
  - `detachWebViewForBackground()`
  - `ensureWebViewAttached()`
  - `updateRestoreState(...)`
  - controller ownership

Next: perform a focused pass over `SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift` and all `TabWebStore+*.swift` extensions to consolidate any behavior drift.

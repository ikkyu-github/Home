# Phase 0–1 (Safari-like) Refactor Report

Scope: **Phase 0 + Phase 1 only** (scan + architecture SSOT decisions). This report is evidence-backed from the current workspace state.

## Phase 0 — Scan results (evidence)

### Source size
- Swift files: **261** (workspace scan)

### Zero-byte / placeholder files (delete immediately)
These are empty and provide no value as source-of-truth artifacts:
- `Dev/diff_PublicAPI_uikithost_ssot.patch`
- `Dev/diff_SafariLikeKit_swift_uikithost_ssot.patch`
- `Dev/move_manifest_tests.txt`

Status: **removed in Phase 0 cleanup**.

### Duplicate files (by content hash)
Detected duplicates are the Xcode asset catalog `Contents.json` files:
- `Assets.xcassets/Contents.json`
- `Assets.xcassets/Shared/Contents.json`
- `Assets.xcassets/RuntimeOnly/Contents.json`
- `Assets.xcassets/DevOnly/Contents.json`

Assessment: these are **expected** and should not be “deduped” (Xcode expects per-folder `Contents.json`).

### Type name collisions across modules (must be eliminated)
A Phase 0 scan found **94** type-name collisions across modules. Representative Safari-like correctness risks:

- **`BrowserSession`** is a real model struct in *two different modules* with different semantics:
  - BrowserCore defines `BrowserSession` as session containing windows (`windows: [BrowserWindow]`).
  - SafariLikeKit defines `BrowserSession` as a single-window snapshot with tabs and split state.
  - This is architecturally dangerous: code review/maintenance will silently use the wrong “session” type.

- **`TabState`** is defined as distinct structs in multiple modules (BrowserCore / CoreKit / Kit). This is exactly the kind of “same name, different meaning” drift that causes duplicated state machines and inconsistent lifecycle.

- Cross-module “bridge” collisions that are currently safe-ish *only because they’re typealiases*:
  - `WebsitePreferences`, `WebsitePreferencesProviding`, `TabThumbnailProviding`, `JSONFileStoreActor`.

Full scan output is in: `Docs/Architecture/phase0_scan_report.md`.

## Phase 1 — SafariLikeContracts as Single Source of Truth (SSOT)

Your requirement (Phase 1 target): `SafariLikeContracts` must be the **only** module that owns these shared types and boundaries:
- WebsitePreferences
- WebsitePreferencesProviding
- TabThumbnailProviding
- persistence interfaces (e.g. JSONFileStoreActor / KeyValueStore)
- shared value types used cross-module

### Current state (already aligned in key areas)
The repo already moved several SSOT types into `SafariLikeContracts`, with backward-compatible typealiases elsewhere:
- `SafariLikeContracts.WebsitePreferences` (struct) with typealiases in BrowserCore and SafariLikeKit.
- `SafariLikeContracts.WebsitePreferencesProviding` (protocol) with typealiases in BrowserCore and SafariLikeKit.
- `SafariLikeContracts.TabThumbnailProviding` (protocol) with typealiases in BrowserCore and SafariLikeKit.
- `SafariLikeContracts.JSONFileStoreActor` (actor) with typealiases in BrowserCore and SafariLikeKit.

This is the correct direction and matches “Contracts owns boundaries + value types”.

### Gaps to close (Phase 1 decisions; implement in later phases)
- **KeyValueStore boundary** is not currently present in `SafariLikeContracts`.
  - Phase 1 decision: define a minimal `KeyValueStore` protocol in Contracts (no concrete storage).
  - Phase 2+ implementation: BrowserCore provides concrete implementations (UserDefaults / file-backed / SQLite) behind the protocol.

- **Eliminate same-name types across modules**.
  - Today, typealiases keep API compatibility, but the end state you requested is stricter: no repeated type names across modules.
  - Phase 2+ decision needed: either (A) accept a breaking API and remove typealias re-exports, or (B) keep aliases temporarily but treat them as migration-only.

## Proposed module tree (Phase 1 target structure)

Goal: “เหมือน Safari จริง” means lifecycle and state ownership are unambiguous:

- `SafariLikeContracts`
  - Pure boundaries + shared value types
  - No UIKit, no SwiftUI, no WebKit
  - Owns: Website prefs, thumbnail/provider protocols, plugin boundary contracts, persistence protocols/value types, session snapshot value types.

- `BrowserCore`
  - Concrete persistence + domain stores implementing Contracts
  - Owns: session persistence store implementations, file/json stores (as impl), data migration
  - Depends on: Contracts

- `SafariLikeCoreKit`
  - WebKit lifecycle & engine orchestration (process pool, web view pool, context routing)
  - Depends on: Contracts
  - Receives BrowserCore implementations via dependency injection (no hard dependency on BrowserCore)

- `SafariLikeKit`
  - High-level orchestration glue for app hosts
  - Should not redefine domain/value types; it composes CoreKit + BrowserCore via Contracts

- `SafariLikeUIKit` / `SafariLikeUXKit`
  - UI-only
  - Must not create runtime singletons inside SwiftUI views; all runtime objects are injected from App composition root.

## Why this prevents duplicated work (Safari-like invariants)
- **Single owner per lifecycle layer**:
  - Session/window/tab snapshot types live in Contracts, persistence lives in BrowserCore, WebKit object lifecycle lives in CoreKit.
- **No duplicated state machines**:
  - Shared state enums/structs are defined once (Contracts), not redefined per module.
- **UI behavior stability**:
  - Phase 1 does not change UI logic; it only formalizes boundaries and prepares a safe consolidation path.

## Immediate cleanup candidates (Phase 0 hygiene)
- Remove workspace-imported logs/artifacts from the source tree:
  - `IncomingLogs/**`
  - `Dev/IncomingLogs/**`
- Remove zero-byte placeholder files listed above.

Status: **completed** (and `.gitignore` now ignores `IncomingLogs/**`).

(These removals do not affect runtime behavior and reduce accidental churn.)

# Phase 1 — Dependency Graph (Curated)

This document turns the generated graph in `build_logs/dependency_graph.*` into an explicit *Safari-like* layering contract.

## Modules (current)

### SafariLikeContracts (Contracts)
- Purpose: Cross-module protocols, value types, identifiers, plugin contracts.
- Allowed imports: Apple SDKs (`Foundation`, etc).
- Allowed module deps: *(none)*

### BrowserCore (Core)
- Purpose: UI-free browser model + policy primitives.
- Allowed module deps: `SafariLikeContracts`
- Forbidden deps: UI/Platform/Engine (`SafariLikeKit`, `SafariLikeUIKit`, `SafariLikeCoreKit`, `SafariLikeUXKit`)

### SafariLikeCoreKit (Core / Engine)
- Purpose: WebKit/runtime engine, tab runtime primitives, lifecycle control.
- Allowed module deps: `BrowserCore`, `SafariLikeContracts`
- Forbidden deps: UI/Host (`SafariLikeKit`, `SafariLikeUIKit`)

### SafariLikeUXKit (Core / UI Support)
- Purpose: UI components/helpers that are safe to share (should stay engine-free).
- Allowed module deps: `SafariLikeContracts`
- Forbidden deps: engine/runtime (`SafariLikeCoreKit`), app orchestration singletons.

### SafariLikeKit (UI + Facade — currently mixed)
- Purpose: SwiftUI views + view models + facade entry points.
- Target allowed module deps (Safari-like): `SafariLikeContracts`, `SafariLikeUXKit`
- Transitional allowance (until split): `SafariLikeCoreKit` may be referenced only from non-UI “runtime glue” code; UI must not import it.

### SafariLikeUIKit (Platform Host)
- Purpose: UIKit host wrappers / composition glue for embedding the SwiftUI facade.
- Target allowed module deps (Safari-like): `SafariLikeKit`, `SafariLikeContracts`
- Forbidden deps: engine internals (`SafariLikeCoreKit`), core (`BrowserCore`) 

### SafariLikeBuiltinPlugins (UI)
- Purpose: Built-in plugin implementations.
- Target allowed module deps (Safari-like): `SafariLikeContracts` only
- Forbidden deps: core/engine (`BrowserCore`, `SafariLikeCoreKit`) to avoid hidden coupling.

## Graph (declared target dependencies — current)
(From `build_logs/dependency_graph.md`)
- `BrowserCore -> SafariLikeContracts`
- `SafariLikeBuiltinPlugins -> SafariLikeContracts`
- `SafariLikeCoreKit -> BrowserCore`
- `SafariLikeCoreKit -> SafariLikeContracts`
- `SafariLikeKit -> BrowserCore`
- `SafariLikeKit -> SafariLikeContracts`
- `SafariLikeKit -> SafariLikeCoreKit`
- `SafariLikeKit -> SafariLikeUXKit`
- `SafariLikeUIKit -> SafariLikeContracts`
- `SafariLikeUIKit -> SafariLikeCoreKit`
- `SafariLikeUIKit -> SafariLikeKit`
- `SafariLikeUXKit -> SafariLikeContracts`

## Graph (target state — allowed edges)

- `SafariLikeContracts -> (none)`
- `BrowserCore -> SafariLikeContracts`
- `SafariLikeCoreKit -> BrowserCore, SafariLikeContracts`
- `SafariLikeUXKit -> SafariLikeContracts`
- `SafariLikeKit -> SafariLikeContracts, SafariLikeUXKit`
- `SafariLikeUIKit -> SafariLikeKit, SafariLikeContracts`
- `SafariLikeBuiltinPlugins -> SafariLikeContracts`
- `App -> SafariLikeKit`

## Phase 1 findings (high-signal violations)

- Platform → UI inversion: `SafariLikeUIKit` imports `SafariLikeKit` (violates strict layering in the generated ruleset).
- Host reaches into engine internals: `SafariLikeUIKit` declares/imports `SafariLikeCoreKit`.
- UI imports Core/Engine types broadly: `SafariLikeKit` imports `BrowserCore` and `SafariLikeCoreKit` across UI/ViewModel paths.
- Built-in plugins import `BrowserCore` (observed imports show coupling that the manifest does not declare).

## How Phase 1 is used

Phase 1 does *not* change behavior. It establishes the dependency contract and enumerates the exact file-level violations so PR-01 can remove them with minimal-diff, structural refactors (primarily: moving types into `SafariLikeContracts`, introducing a strict facade boundary, and relocating runtime glue out of UI folders).

# Architecture (Layer Rules)

This repo intentionally follows a Safari-like layering model.
The goal is to keep UI thin, keep domain/core portable, and keep WebKit policy centralized.

## Layer Rules (enforced)

## Current dependency boundaries (from `Package.swift`)

This is the *actual* module dependency graph as declared today:

- `SafariLikeContracts`
  - Depends on: `swift-log`, `swift-collections`
  - Must stay pure (types/protocols/constants). **Must not import `WebKit` / UI frameworks.**
- `BrowserCore`
  - Depends on: `SafariLikeContracts` (+ `Logging`, `Collections`)
  - Domain + persistence. **Must not import `WebKit` / `UIKit` / `SwiftUI`.**
- `SafariLikeUXKit`
  - Depends on: `SafariLikeContracts`
  - UI policies + view-model-ish orchestration that is still WebKit-agnostic.
  - **Must not import `WebKit`.**
- `SafariLikeCoreKit`
  - Depends on: `BrowserCore`, `SafariLikeContracts` (+ `Logging`, `Collections`)
  - Engine/runtime. *Allowed* to import `WebKit`.
- `SafariLikeKit`
  - Depends on: `BrowserCore`, `SafariLikeCoreKit`, `SafariLikeUXKit`, `SafariLikeContracts` (+ `Logging`, `Collections`)
  - Facade + composition/wiring.
- `App/` (Xcode target)
  - Imports: `SafariLikeKit` (+ `SafariLikeContracts` where needed)
  - **Must not import:** `BrowserCore`, `SafariLikeCoreKit`, `SafariLikeUXKit`.

The intent is one-way dependencies with a single public facade: `App → SafariLikeKit → (CoreKit/UXKit/BrowserCore/Contracts)`.

### App target (`/App`)

Allowed imports:
- `SafariLikeKit`
- `SafariLikeContracts`
- Apple frameworks (e.g. `SwiftUI`, `UIKit`, `Foundation`)

Forbidden imports:
- `BrowserCore`
- `SafariLikeCoreKit`
- `SafariLikeUXKit`

Rationale: the App should depend only on the public facade (`SafariLikeKit`) + SSOT contracts.

Additional hard rules:

- **No policy/logic inside SwiftUI Views.**
  - Views may format strings, map state → UI, and emit events.
  - Views must not implement decision policies (activation, budgeting, WebKit lifecycle rules, navigation policy, etc.).
  - Put decision logic in `SafariLikeUXKit` (UI policy/orchestration) or `SafariLikeCoreKit` (engine/runtime policy).

- **No `.shared` for scene/tab/window-bound state.**
  - Anything that depends on scene/window/tab identity must be instance-scoped and injected (e.g. via `SceneRuntimeContext`, tab-owned stores, or composition roots).
  - Singletons are only acceptable for immutable constants or true process-wide stateless helpers.

### SafariLikeKit (facade)

Allowed imports:
- `SafariLikeContracts` (SSOT)
- `SafariLikeCoreKit` (engine/runtime)
- `BrowserCore` (models/persistence)
- `SafariLikeUXKit` / `UIKit` / `SwiftUI` as needed for UI

Rationale: `SafariLikeKit` is where composition happens (UI + runtime + wiring).

## Public API boundary (enforced by access control)

Rule:
- The App may hold a `SceneRuntimeContext` (for scene-scoped UI/diagnostics), but it must not be able to reach CoreKit runtime handles (tab registries, pools, WebContext managers/routers, etc.).

Rationale:
- Prevents bypassing the canonical runtime flow:
  `SceneRuntimeContext → TabRegistry → WebViewPool → WebContext`.
- Ensures WebKit lifecycle remains controlled by the engine layer and cannot be mutated directly from the App.

See also:
- `Docs/API_BOUNDARY.md`

### BrowserCore (domain / persistence)

Allowed imports:
- `SafariLikeContracts`
- non-UI Apple frameworks such as `Foundation`

Forbidden imports:
- `UIKit`
- `SwiftUI`
- `WebKit`

Rationale: `BrowserCore` must remain platform/UI independent.

### SafariLikeCoreKit (engine)

Rule:
- Must not be imported directly by the App target.

Rationale: CoreKit is an internal engine. App should go through `SafariLikeKit`.

## Guardrails that are enforceable

This repo uses a mix of script-based checks and SwiftLint to make rules executable.

- Script guard: `Dev/Tools/Scripts/architecture_guard.sh`
- SwiftLint (local / CI-pluggable): see `.swiftlint.yml` and `Scripts/run_swiftlint.sh`

## SSOT / Duplicate Symbol Rule

Some names are treated as “SSOT types” and must not be declared in multiple modules.
Examples:
- `DefaultURLs`
- `WebsitePreferences` / `WebsitePreferencesProviding`

If these appear in multiple `RuntimePackages/*/Sources/*` modules, the checker fails.

## How to run the checks

From repo root:


Or via Xcode Debug build (automatic):

## CI guard: architecture rules

Run locally:

```bash
bash Dev/Tools/Scripts/architecture_guard.sh
```

Notes:
- Uses `rg` (ripgrep) when available; falls back to `grep`/`find`.
- Fails CI (non-zero exit) when violations are found.

This script enforces:
- App-layer imports: files under `App/` must not import lower layers (`SafariLikeUIKit`, `SafariLikeCoreKit`, `BrowserCore`, `SafariLikeUXKit`).
- WebView construction: `WKWebView(` must only occur in `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift`.
- Singleton state heuristic (CI error): any Swift file that declares a `shared` singleton (e.g. `static let shared`) is flagged if it also contains suspicious per-scope state keywords (scene/tab/window IDs, registries/caches/maps) or UI retention keywords (`WKWebView`, `UIViewController`, `Coordinator`).
  - Fix: move mutable per-scene/per-tab/per-window state under `SceneRuntimeContext` (scene-owned) or tab-owned stores (`TabRegistry`/`TabWebStore`), or refactor to injected instances.
  - Opt-out (rare): add `// ARCH_GUARD:ALLOW_SINGLETON_STATE` in the file to silence this heuristic for that file. Only use this for reviewed false positives, and include a nearby explanation.
- Scene-owned services must not be global: usage like `SceneRuntimeContext.shared` or `TabRegistry.shared` is forbidden.
## Example violation output

Example: App importing CoreKit:

```
== ERROR: App must not import BrowserCore/CoreKit/UXKit (App imports only SafariLikeKit + SafariLikeContracts) ==
App/SomeFile.swift:3:import SafariLikeCoreKit

Architecture enforcement failed.
```

Example: Duplicate SSOT symbol:

```
== ERROR: Duplicate symbol across modules: DefaultURLs ==
Found definitions in modules:
  - SafariLikeContracts
  - SafariLikeKit
Matches:
RuntimePackages/SafariLikeContracts/Sources/...:12:public struct DefaultURLs
RuntimePackages/SafariLikeKit/Sources/...:44:internal struct DefaultURLs

Architecture enforcement failed.
```

---

Notes:
- A deeper, historical architecture writeup exists at `Dev/Docs/ARCHITECTURE.md`, but this file is the short, enforceable rule set.

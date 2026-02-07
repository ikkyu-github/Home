# PR-01 Plan — Phase 1 Follow-on (Structural Only)

Goal: remove the highest-impact layer violations *without behavior changes*, while keeping diffs minimal and making later Safari-parity work deterministic.

## Principles
- No new singletons.
- No behavior changes: focus on moves, type extraction, protocol/value-type surfacing.
- Prefer `SafariLikeContracts` for shared types; prefer a facade API from `SafariLikeKit`.
- UI (SwiftUI / ViewModel / Views) must not import `BrowserCore` or `SafariLikeCoreKit`.
- `SafariLikeUIKit` must not import engine internals.

## Suggested commit sequence

### Commit 1 — Add enforcement + docs as source of truth
- Keep these Phase 1 artifacts in-tree:
  - `Docs/Architecture/Phase1/dependency_graph.md`
  - `Docs/Architecture/Phase1/forbidden_imports.md`
  - `Docs/Architecture/Phase1/PR-01-plan.md`
- Add a CI-friendly rerun command (see `Dev/Tools/Scripts/phase1_rerun_scan.sh`).

### Commit 2 — Fix `SafariLikeUIKit` boundary (host must not import engine)
- Move any engine-touching code out of `SafariLikeUIKit` into `SafariLikeKit` (or into `SafariLikeCoreKit` if it is truly engine-owned).
- Replace `SafariLikeUIKit -> SafariLikeCoreKit` usages with:
  - `SafariLikeKit` facade entry points, and
  - `SafariLikeContracts` protocols/value types.
- Update `Package.swift` for `SafariLikeUIKit` to remove `SafariLikeCoreKit` dependency.

### Commit 3 — Make `SafariLikeBuiltinPlugins` contracts-only
- Ensure built-in plugins depend only on `SafariLikeContracts`.
- For any plugin implementation currently importing `BrowserCore`, move the required configuration/value types into `SafariLikeContracts`.
- Add adapters/registration glue in a non-UI runtime area (owned by facade/engine), not in the plugin module.

### Commit 4 — Split “UI” vs “runtime glue” inside `SafariLikeKit`
Two options (choose one; Option A is smaller diff):

**Option A (smaller diff, file-level enforcement)**
- Establish a folder contract:
  - `Sources/SafariLikeKit/UI/**` and `Sources/SafariLikeKit/ViewModel/**` must import only `SafariLikeContracts` + `SafariLikeUXKit` (+ Apple SDKs).
  - Engine glue lives under `Sources/SafariLikeKit/RuntimeGlue/**` and is the only area allowed to import `SafariLikeCoreKit`.
- Extract any UI-referenced CoreKit/BrowserCore types into `SafariLikeContracts` (value types + protocols).
- Update UI call sites to use Contracts types.

**Option B (cleaner long-term, bigger diff)**
- Introduce a new target (e.g. `SafariLikeRuntimeGlue`) that depends on `SafariLikeCoreKit` and `BrowserCore`.
- Make `SafariLikeKit` (UI) depend on `SafariLikeRuntimeGlue` only via `SafariLikeContracts` + facade protocols.

### Commit 5 — App imports facade only
- Remove any direct `BrowserCore` / `SafariLikeCoreKit` imports from `App/**`.
- If App needs shared value types, keep them in `SafariLikeContracts`; otherwise route everything through `SafariLikeKit`.

## Verification gates
- `python3 Dev/Tools/Scripts/dependency_graph.py` produces no new violations (or fewer, monotonically).
- `python3 Dev/Tools/Scripts/phase1_forbidden_imports_report.py --json build_logs/dependency_graph.json` shows decreasing counts.
- Xcode build remains clean (no warnings).

## Notes
- The current module shape has `SafariLikeKit` mixing UI + runtime glue; PR-01 should *not* try to fully redesign the architecture. The goal is to establish an enforceable seam so later phases can move ownership cleanly.

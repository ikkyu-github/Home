# Final Architecture & Performance Audit (No Runtime Changes)

This document defines the **audit-only** checklist and procedures for keeping the repo aligned with the architecture and performance guardrails introduced across PR1–PR15.

**Non-goals for this audit PR**
- No new features.
- No refactors that change runtime behavior.
- Only: scripts + documentation + DEBUG-only instrumentation.

## 1) Architecture rules (what is enforced, and where)

### Rule A — App layer import boundary
**Policy:** `App/` must not import lower layers directly (WebKit / CoreKit / BrowserCore / UXKit).

**Enforced by**
- `Dev/Tools/Scripts/architecture_guard.sh` (Rule 1)
- `Scripts/check_import_boundaries.sh`

**What to do if it fails**
- Move the dependency behind `SafariLikeKit`/Contracts APIs.
- If the App needs a type, expose it via a small façade in `SafariLikeKit` rather than importing lower layers.

### Rule B — WKWebView construction boundary
**Policy:** `WKWebView(` must only appear in the WebView factory/pool.

**Enforced by**
- `Dev/Tools/Scripts/architecture_guard.sh` (Rule 2)
- `Scripts/repo_guard.sh` (WebKit boundary enforcement)

**Allowlist**
- `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift`

### Rule C — No scene/tab/window scoped state in global singletons
**Policy:** new `static let shared` that retains scene/tab/window mutable state is forbidden.

**Enforced by**
- `Dev/Tools/Scripts/architecture_guard.sh` (Rule 3 heuristic)
- `Scripts/repo_guard.sh` (singleton regression guard for SafariLikeKit)

**Notes**
- The guard is intentionally heuristic: it’s designed to catch regressions early.
- Opt-out marker (rare): `// ARCH_GUARD:ALLOW_SINGLETON_STATE`.

### Rule D — Scene-owned services must not be global (`.shared`)
**Policy:** scene-owned types must be injected/owned per scene; they must not have `.shared` usages.

**Enforced by**
- `Dev/Tools/Scripts/architecture_guard.sh` (Rule 4)

## 2) DEBUG-only performance & memory baselines

The repo already captures several runtime metrics in DEBUG via the performance overlay model.

### Where metrics come from
- WebView counts + pool snapshots: `SafariLikeCoreKit.WebViewPool` notifications
- Attach performance: scene-scoped `SafariLikeKit.PerformanceOverlayModel`
- Snapshot cache budgets/metrics: `SafariLikeKit.SnapshotService` debug metrics
- (Added by this audit) Process memory footprint: sampled in DEBUG only and surfaced in the overlay

### Baseline capture scenarios (template)

Populate the table below on at least one representative device class (e.g. “iPhone 15 Pro, iOS 17.x”) and keep the ranges updated as part of performance-focused PRs.

| Scenario | Metric(s) | How to capture | Baseline (range) |
|---|---|---|---|
| Cold launch → first UI | `app.launch`, `to first.ui` | Enable overlay; relaunch app | _(fill in)_ |
| Cold launch → first webview ready | `to first.webview` | Open a tab to a common site | _(fill in)_ |
| New tab attach → ready | `attach→ready` (last / p50) | Open N new tabs; read p50 | _(fill in)_ |
| New tab attach → first paint | `attach→paint` (last / p50) | Same as above | _(fill in)_ |
| Steady-state webviews | `live.webviews`, `wv.pool` | Open 5–10 tabs; background/foreground | _(fill in)_ |
| Process footprint (DEBUG) | `footprint` (current/peak) | Observe during scenarios above | _(fill in)_ |

### Overlay usage
- DEBUG only
- Toggle: triple-tap anywhere (see diagnostics overlay gesture)

## 3) Regression checklist (must-answer questions)

Use this checklist for any PR touching: tabs, WebKit lifecycle, scene lifecycle, session restore, snapshotting, or caches.

**Architecture & isolation**
- Did you add any imports under `App/` that cross the App boundary?
- Did you introduce any new `WKWebView(` construction outside the WebView pool?
- Did you introduce any new `static let shared`? If yes, does it retain scene/tab/window scoped state?
- Did you add any `.shared` usage for scene-owned types (e.g. `SceneRuntimeContext`, `TabRegistry`)?

**WebView lifecycle**
- Does every new WebView come from the pool/factory?
- Are WebViews released on scene shutdown (no new retained references)?
- Do pool counts remain bounded under common tab switching flows?

**Budgets & performance**
- Did you increase any explicit budgets (snapshot bytes, pool size, etc.)? Why?
- Did you add any new caches? Are they bounded, and is eviction behavior defined?
- Do attach→ready and attach→firstPaint regress vs baseline?
- Does process footprint regress vs baseline during the same scenario?

**Privacy**
- Are private-mode resources isolated (stores, registries, pools, contexts)?
- Are downloads / storage paths consistent with the privacy audit docs?

## 4) How to run the audit

### One-command runner
- `bash Scripts/run_final_audit.sh`

### Manual steps
- Architecture rules: `bash Dev/Tools/Scripts/architecture_guard.sh`
- Repo hygiene + anti-bloat: `bash Scripts/repo_guard.sh`
- Unit tests (SwiftPM):
  - `Dev/Tools/Scripts/spm.sh RuntimePackages/BrowserCore test`
  - `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeCoreKit test`
  - `Dev/Tools/Scripts/spm.sh RuntimePackages/SafariLikeKit test`

## 5) Current known validation gap

As of the audit snapshot that introduced this document, `SafariLikeKitTests` include a leak-sentinel test that fails due to scene-owned objects remaining alive after teardown.

This audit PR does **not** fix that leak because doing so would likely require runtime behavior changes. Track it as a follow-up bugfix PR focused specifically on teardown correctness.

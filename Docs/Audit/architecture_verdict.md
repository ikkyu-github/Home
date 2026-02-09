# Safari-Grade Architecture Verdict (Repo Audit)

Date: 2569-02-03

## Scope & Method
This audit is based on:
- The enforceable rules in `ARCHITECTURE.md`.
- Repository-wide code searches for:
  - `WKWebView(` construction sites
  - activation/attach/detach APIs (`activatedStore`, `activate(using:)`, `deactivate`, `attachIfNeeded`, `AttachmentCoordinator`)
  - bypass patterns (`.shared`, default fallbacks, direct WebKit ownership from UI)
- Manual review of the primary runtime path classes:
  - App layer (`AppRootView`, `AppBrowserSessionController`)
  - SafariLikeKit scene boundary (`SceneRuntimeContext`, `SceneRuntimeRegistry`, `TabManager`)
  - SafariLikeCoreKit activation boundary (`TabRegistry`, `TabWebStore`, `WebViewPool`, `WebContextManager`, `WebContextRouter`, `WebContext`)

This is an architectural audit, not a full functional correctness proof.

---

## Safari Parity Score
**Score:** **82%**

**How the score is computed (roughly):**
- Each category below is weighted equally.
- A category marked **Fail** caps that category to ~50% even if partial progress exists.

---

## Category Verdicts (Pass/Fail)

| Category | Verdict | Notes |
|---|---:|---|
| Layering | **PASS** | Clear enforced rules in `ARCHITECTURE.md`. App imports `SafariLikeKit`/`SafariLikeContracts` only; BrowserCore stays UI/WebKit-free.
| Scene isolation | **FAIL** | Several global singletons hold mutable, window/scoped state or caches keyed by window/tab IDs (`WebContextManager.shared`, `AppLifecycleCoordinator.shared`, `WebViewPool.shared` fallback paths). Isolation is *mostly* respected in practice via windowID keys, but Safari-grade requires stronger “no accidental cross-scene” guarantees.
| WebView budgeting | **PASS (with risks)** | Budget is centralized via `TabRegistry` caps + LRU and reinforced by runtime policies. However, `.shared` pool fallbacks remain and can undermine per-scene ownership in edge cases.
| Attachment determinism | **PASS** | Deterministic single-writer model is documented and implemented (`AttachmentCoordinator` + generation tokens). Scene wires signals into coordinator.
| Policy decisions | **PASS** | Snapshot→Decision patterns are established (`RenderBudgetPolicy`, `WebViewRequirementPolicy`, `WebContentVisibilityPolicy`, navigation policy evaluator). UI is mostly declarative and not owning policy.
| Dead code / legacy glue | **FAIL** | Multiple explicit “legacy/compatibility shim” paths remain (notably in `WebViewPool` and `TabWebStore`), plus `.shared` singletons used as fallbacks. This is functional, but not Safari-grade cleanliness.

---

## Evidence Highlights

### Layering
- `ARCHITECTURE.md` defines enforceable import boundaries.
- `BrowserCore` is explicitly UI/WebKit-free (design intent is consistent with current sources).

### Scene isolation (key problems)
- **Global mutable caches keyed by window/tab:**
  - `SafariLikeCoreKit/WebKit/Context/WebContextManager.shared` holds `contexts` and `configurationCustomizersByWindowID`.
  - If window teardown does not call `tearDownWindow(windowID:)`, the customizer can retain window-scoped objects.
- **Global fallbacks that can bypass per-scene registration:**
  - `SafariLikeCoreKit/WebKit/Pool/WebViewPool.shared` exists.
  - `TabRegistry.webViewPool(for:)` falls back to `.shared`.
  - `TabWebStore.activate(using pool: WebViewPool? = nil)` falls back to `.shared`.

Safari-grade expectation: missing per-scene registration should be a loud failure (precondition) in debug/dev, not a silent global fallback.

### WebView budgeting
- `TabRegistry.activatedStore(...)` is the centralized activation gate with capacity enforcement.
- UI-side lifecycle hooks were previously a duplication risk; the current architecture favors runtime enforcement.
- **But** the pool ownership model is still in migration: `WebContext` constructs WKWebView; `WebViewPool` “adopts” it for budgeting.

### Attachment determinism
- Documented invariants (single writer, generation tokens, deferred publish) exist in `Docs/ATTACHMENT_STATE_MACHINE.md`.
- `SceneRuntimeContext` is the router; `AttachmentCoordinator` owns transitions.

### Policy decisions
- `Docs/POLICY_DOMAIN_MAP.md` describes and the code implements “pure evaluator + applier” discipline.

---

## Safari-Grade Criteria Checklist (Strict)

- UI does not own WebKit/policy: **Mostly true**.
  - UI has a `UIViewRepresentable` wrapper (`SafariLikeKit/Platform/Web/WebView.swift`) which is acceptable.
  - Risk: any activation triggers from SwiftUI lifecycle must remain prohibited.

- All WKWebView creation/activation centralized via TabRegistry/WebViewPool: **Not fully true**.
  - `WKWebView` is also constructed in `WebContext`.
  - Several code paths accept/assume `.shared` fallback pools.

- No new global mutable state: **Respected by recent work**, but existing global mutable state is still present and should be reduced.

---

## Immediate Recommendation
To reach Safari-grade, the next milestone is **eliminating `.shared` fallbacks** and making **per-scene registration mandatory**, then tightening tests and CI to prevent regressions.

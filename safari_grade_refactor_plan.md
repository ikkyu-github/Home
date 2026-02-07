# Safari-Grade Refactor Plan (PR-by-PR)

Date: 2569-02-03

Goal: reach a Safari-grade architecture where:
- UI is declarative and does not own policy or activation.
- All WKWebView creation/activation is centralized through `TabRegistry` + per-scene `WebViewPool`.
- No global mutable state holds scene/tab runtime state.
- Behavior is deterministic and testable (especially under multi-window).

Each PR is intentionally small and reviewable.

---

## PR-01: Layer enforcement
**Objective:** Make architecture regressions hard to introduce.

Changes (small diffs):
- Add/extend repo checks to assert:
  - App target does not import `SafariLikeCoreKit` / `BrowserCore` directly.
  - `BrowserCore` has no `WebKit`, `UIKit`, `SwiftUI` imports.
  - `SafariLikeKit/UI/**` does not call activation APIs (`activatedStore`, `activate(using:)`, `ensureWebViewAttached`).
- Add a “bypass grep” list to CI (or to the existing architecture check script).

Acceptance criteria:
- CI fails if forbidden imports or activation calls appear in UI.

---

## PR-02: Singleton inventory/classification
**Objective:** Make global state explicit and categorized.

Changes:
- Produce a generated markdown inventory (checked in) listing every `static let shared`/singleton-like global with:
  - scope: process / app / window / debug-only
  - mutable? (yes/no)
  - holds scene/tab state? (yes/no)
  - teardown requirements

Targets to classify early:
- `WebViewPool.shared`
- `WebContextManager.shared`
- `WebContextRouter.shared`
- `EngineController.shared`
- `PolicyCenter.shared`
- `AppLifecycleCoordinator.shared`

Acceptance criteria:
- Reviewers can point to a single inventory file to justify any remaining singleton.

---

## PR-03: Legacy/stub cleanup
**Objective:** Reduce surface area for bypasses and remove “compatibility shims” where safe.

Changes (examples):
- Fence legacy APIs behind tighter visibility:
  - Make `TabWebStore.ensureWebViewAttached()` internal to CoreKit (or remove if unused).
  - Reduce use of `WebViewPool.acquireWebView(for:configuration:)` legacy API.
- Remove dead/stale glue that exists only for older wiring.

Acceptance criteria:
- No public API that can create/activate WKWebView without passing through `TabRegistry`.

---

## PR-04: Remove `WebViewPool.shared` fallback (require per-scene registration)
**Objective:** Make per-scene WebView ownership mandatory.

Changes:
- In `TabRegistry`:
  - Replace `webViewPoolByPaneID[paneID] ?? .shared` with a strict requirement:
    - in DEBUG: `preconditionFailure` with a clear message
    - in RELEASE: either safe no-op suppression or controlled fatal (team decision)
- In `TabWebStore`:
  - Remove `pool ?? .shared` default; require a pool to be provided or previously attached.
  - Remove `attachedWebViewPool ?? .shared` fallback in deactivate/invalidate.
- In `SceneRuntimeContext` / session bootstrap:
  - Ensure pools are always registered for all panes before any activation is possible.

Acceptance criteria:
- It is impossible (or loudly fails in debug) to create/activate a WKWebView without a per-scene pool.

---

## PR-05: Attachment determinism tests
**Objective:** Prove the deterministic state machine holds under concurrency.

Add tests:
- `AttachmentCoordinator`:
  - generation token prevents stale timeout commits
  - request idempotency (same state request is no-op)
  - “publish after yield” does not publish stale state
- Integration tests at SafariLikeKit level:
  - overview mode never triggers activation
  - switching tabs does not create more than budgeted live views

Acceptance criteria:
- Tests fail on known race regressions (attach-after-detach, double activation).

---

## PR-06: Automated Safari parity checklist
**Objective:** Turn the parity checklist into an executable gate.

Changes:
- Implement a script that validates:
  - no new WKWebView construction sites outside the approved factory(s)
  - no `.shared` fallbacks in activation chain
  - no UI-owned activation triggers
- Run it in CI and (optionally) as an Xcode build phase.

Acceptance criteria:
- The checklist becomes a deterministic, automated pass/fail.

---

## Suggested Sequencing
- PR-01 first (tighten guardrails)
- PR-02 next (make global state explicit)
- PR-04 early (it enforces the core Safari-grade invariant)
- PR-03 then PR-05/06 to remove shims and lock in behavior with tests

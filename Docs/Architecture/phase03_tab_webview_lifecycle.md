# Phase 03 — Tab & WKWebView Lifecycle (Safari-like)

## Goals

- Make tab lifecycle deterministic and resilient to SwiftUI/view churn.
- Prevent “ghost” async callbacks after a tab transitions state.
- Treat teardown races as recoverable (log + safe fallback), not `assertionFailure`.

## Canonical vs UI Lifecycle Vocabulary

The persisted canonical lifecycle enum is `BrowserCore.TabLifecycleState`:

- Canonical: `cold`, `warming`, `active`, `suspended`, `discarded`, `closed`
- UI-facing alias: `BrowserCore.TabLifecycleState.Phase`:
  - `created`  → `cold`
  - `restoring` → `warming`
  - `active` → `active`
  - `background` → `suspended`
  - `discarded` → `discarded` (and `closed` maps to `discarded` for UI)

This keeps persistence stable while letting the UI / product language match Safari-like terms.

## Ownership Rules (Single Source of Truth)

### Who owns `WKWebView`?

- **Owner**: `SafariLikeCoreKit.TabRegistry` / `SafariLikeCoreKit.TabWebStore` (via `EngineController` / pooling).
- **UI**: never creates, destroys, or directly configures `WKWebView`.
- **UIKit/SwiftUI bridge** (`SafariLikeKit.WebView`): only attaches/detaches a provided `WebViewHandle.webView` to a container view.

### Who may destroy / recreate?

- Only the runtime layer that owns pooling/budget (CoreKit + lifecycle controller) may:
  - detach/freeze/discard webviews
  - destroy and recreate runtimes
  - apply render budget and activation suppression

The app/UI layer expresses intent (select tab, show overview, split mode) but does not mutate WebKit resources directly.

## State Machine (Tab-level)

A tab has two related axes:

1) **Lifecycle**: created/restoring/active/background/discarded/(closed)
2) **Runtime attachment**: attached vs detached (whether a `WKWebView` is currently mounted/active)

### Simplified lifecycle transitions

```
(created) ── user selects / URL load ─▶ (active)
   │                               │
   │ session restore prewarm        │ app goes background / overview / budget
   ▼                               ▼
(restoring) ── webview ready ───▶ (active) ─────────────▶ (background)
   │                                                    │
   │ discard policy / memory pressure                    │ discard policy / memory pressure
   ▼                                                    ▼
(discarded) ◀──────────── restore/activate ─────────── (background)
   │
   └─ close tab ─▶ (closed)  (terminal)
```

Key invariants:

- `discarded` means the `WKWebView` is gone; a snapshot and/or `TabRestoreToken` may remain.
- `background` means the tab exists but should not keep “foreground work” alive.

## Cancellation & “No Ghost Work”

### Rule

Every async task that can outlive a single UI update must be scoped to a `tabID` and cancelled on lifecycle transitions.

Mechanisms used in this repo:

- `SafariLikeKit.TabTaskRegistry` is the tab-scoped task registry.
- `TabManager.setLifecycle(tabID:lifecycle:runtimeAttachment:)` cancels tasks on transitions:
  - `discarded` → cancel all
  - `closed` → cancel all (except close)
  - `suspended/background` → cancel pending activation/load/restore work

For binding-time races, `TabCoordinator` also uses a **binding transaction ID** (`tx`) and ignores late store events.

### Example pattern (TabCoordinator)

- Bind the active tab with a transaction.
- Register all side-effecting tasks under `TabTaskRegistry`.
- In every callback:
  - verify transaction is still current
  - exit early if cancelled

Pseudo-shape (see implementation in `SafariLikeKit/Runtime/TabRuntime/TabCoordinator.swift`):

```
let tx = manager.beginBindingTransaction(...)
manager.tabTasks.replaceTask(tabID: tabID, key: .bindActiveTab) {
  Task { @MainActor in
    guard manager.isCurrentBindingTransaction(tx) else { return }
    let store = await runtime.activate(...)
    guard manager.isCurrentBindingTransaction(tx) else { return }

    store.observeState { state in
      guard manager.isCurrentBindingTransaction(tx) else { return }
      // update UI + session model (deduped)
    }

    // one-shot restore work
    manager.tabTasks.replaceTask(tabID: tabID, key: .scrollRestore) {
      Task { @MainActor in
        guard manager.isCurrentBindingTransaction(tx) else { return }
        guard Task.isCancelled == false else { return }
        // apply restore
      }
    }
  }
}
```

## Assertions vs Recovery

Recoverable lifecycle races are logged + safely defaulted:

- WebKit policy decisions: if the store is already torn down, default to allow/deny safely and log.
- UI attachment validation: attempt to reattach on transient SwiftUI container churn; log if still inconsistent.

Assertions are reserved for true programmer errors (e.g., breaking the global WebView budget invariant).

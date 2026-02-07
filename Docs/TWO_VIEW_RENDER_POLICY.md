# Two-view max render policy (Safari-style)

## Goal
Guarantee **no more than 2 live `WKWebView` instances per window**:
- **Active tab**: has a live web view.
- **Preview tab (optional)**: has a live web view.
- **All other tabs**: are **frozen** (snapshot-first) and release their web view.
- **Overview**: snapshot-only (0 live web views).

## Render modes
UI-facing `TabState.renderMode` values:
- `active`: the focused/active pane tab.
- `preview`: the companion live tab (split) or transient binding target (non-split).
- `frozen`: no live web view; may have `snapshotData`.
- `discarded`: evicted/closed tab (lifecycle-driven).

Snapshot presence is represented by `TabState.snapshotData`.

## Enforcement point
The single enforcement hook is:
- `TabLifecycleController.applyRenderBudget(reason:)`

It:
1) Picks at most 2 “desired live” tab IDs (active + preview).
2) Freezes all other live tabs (captures snapshot first).
3) Ensures desired live tabs are activated (best-effort).
4) Updates `TabState.renderMode` for UI/diagnostics.

## Preview definition
- Split enabled: preview is the **non-active** split pane.
- Split disabled: preview is the **binding target** (if distinct from active), capped so it never becomes a third live web view.

## Flow
```mermaid
flowchart TD
  A[applyRenderBudget(reason)] --> B{isPerformingSessionRestore?}
  B -- yes --> X[return]
  B -- no --> C{overview visible?}

  C -- yes --> D[keepSet = ∅]
  D --> E[freeze any live tabs (snapshot first)]
  E --> F[set renderMode: discarded or frozen]
  F --> Z[done]

  C -- no --> G[compute activePaneTabID]
  G --> H[compute previewTabID]
  H --> I[desiredLiveTabIDs = [active, preview] (max 2)]
  I --> J[keepSet = desiredLiveTabIDs ∩ alive candidates]
  J --> K[freeze candidates not in keepSet (snapshot first)]
  K --> L[activate tabs in desiredLiveTabIDs if needed]
  L --> M[set renderMode: active/preview/frozen/discarded]
  M --> Z[done]
```

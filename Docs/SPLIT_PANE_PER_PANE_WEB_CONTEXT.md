# Split Pane: Per-Pane Web Context

This document describes the per-pane web isolation model used by split-pane browsing.

## Goals / Invariants

- **Per-pane isolation:** panes must not directly share `WKWebView` instances or the `WebContext` used to create them.
- **Tab ↔ pane binding:** every tab has an explicit `paneID` persisted in `TabState`.
- **Pane moves are safe:** when a tab moves panes, any attached WebView is detached so the next activation reattaches under the destination pane context.
- **Geometry updates are scoped:** rotation/resize updates only touch metrics for panes that are currently visible.

## Key Types

- `PaneContext` (SafariLikeKit)
  - `paneID: PaneID`
  - `webViewPool: WebViewPool` (one pool per pane)
  - `metrics: PaneMetrics` (per-pane container + safe-area)

- `TabState.paneID` (SafariLikeKit)
  - Persisted via `Codable`
  - Used as the source of truth for which `PaneContext` a tab belongs to

- `TabRegistry` + `TabWebStore` (SafariLikeCoreKit)
  - Registry selects the correct pool for a pane and activates stores using that pool.
  - Store remembers which pool it used so deactivation/invalidation routes back to the same pool.

## Architecture Diagram

```mermaid
flowchart LR
  subgraph UI[UI Layer]
    R[SplitBrowserRootView]
  end

  subgraph Kit[SafariLikeKit]
    TM[TabManager]
    TS[TabState\n(paneID persisted)]
    PCp[PaneContext.primary\n- WebViewPool: primary\n- PaneMetrics]
    PCs[PaneContext.secondary\n- WebViewPool: secondary\n- PaneMetrics]
    TR[TabRuntime]
  end

  subgraph Core[SafariLikeCoreKit]
    REG[TabRegistry\n(webViewPoolByPaneID)]
    STORE[TabWebStore\n(attachedWebViewPool)]
    POOLp[WebViewPool(primary)]
    POOLs[WebViewPool(secondary)]
    WCM[WebContextManager]
    WK[WKWebView]
  end

  R -->|stable geometry| TM
  TM -->|updates visible pane metrics| PCp
  TM -->|updates visible pane metrics| PCs

  TM -->|select/assign| TS
  TM -->|creates runtime with paneID| TR

  TR -->|activatedStore(tabID,paneID,role)| REG
  REG -->|activate(using: pool)| STORE

  PCp --> POOLp
  PCs --> POOLs

  REG -->|paneID=primary| POOLp
  REG -->|paneID=secondary| POOLs

  STORE -->|context(windowID,paneID,privacy)| WCM
  STORE -->|acquireWebView(for:tabID,context)| POOLp
  STORE -->|acquireWebView(for:tabID,context)| POOLs
  STORE --> WK
```

## Runtime Rules (What prevents cross-pane sharing)

- Pane moves call `assignTab(_:to:)`, which updates `TabState.paneID` and freezes any attached store (`freezeWebView()`), forcing a detach.
- `TabRegistry` routes activation through a pane-specific pool: `store.activate(using: webViewPool(for: paneID))`.
- `TabWebStore` stores `attachedWebViewPool` so `deactivate()` / `invalidate()` routes to the same pool that created the WebView.

## Rotation / Resize

`SplitBrowserRootView` calls `TabManager.updateVisiblePaneMetrics(containerSize:safeAreaInsets:)`:
- On initial appear
- After `LayoutStabilizer` finishes stabilizing following geometry changes

Only the contexts for panes that are currently visible are updated.

## Notes / Scope

- This refactor focuses on per-pane WebView ownership via per-pane `WebViewPool` instances and per-pane metrics storage.
- `WebContextManager` remains shared, but the context is keyed by `windowID + paneID + privacyMode (+ route)`, so pane identity still participates in WebKit context selection.

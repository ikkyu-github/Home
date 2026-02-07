# Phase 3 — Contract Hardening (Safari-like)

Objective: harden cross-layer contracts so internal refactors inside `SafariLikeCoreKit` remain deterministic and higher layers (`SafariLikeKit`) compile without needing implementation knowledge.

This phase focuses on the contract boundaries between:
- `SceneRuntimeContext` (SafariLikeKit)
- `TabRegistry` / `TabWebStore` (SafariLikeCoreKit)
- Policy / Attachment / Lifecycle layers

## 1) Contract surfaces

### `SafariLikeCoreKit.TabWebStore`

**Who calls it**
- SafariLikeCoreKit: `TabRegistry`, WebKit delegate bridge (`WebKitPolicyBridge`), internal TabWebStore controllers.
- SafariLikeKit: runtime and view-model layers consume tab state, attachment signals, and (via handle) access to the live `WKWebView`.

**Stable contract (intended cross-layer API)**
- Lifecycle + WebView ownership
  - `activate()` / `activate(using:)`
  - `ensureWebViewAttached()`
  - `detachWebViewForBackground()`
  - `discardWebView()`
  - `invalidate()`
- Performance
  - `performanceTier`
  - `setPerformanceTier(_:)`
- Restore
  - `updateRestoreState(currentURL:lastKnownTitle:)`
  - `uxRestoreController` (read-only consumption via `uxRestoreStatePublisher` preferred)
- State observation
  - `state: TabWebStoreState`
  - `observeState(_:)` / `removeStateObserver(_:)`
- UI/Runtime bridging (read-only / callback based)
  - `webViewHandle` (the only supported way for other modules to access the live `WKWebView`)
  - `webViewRealityPublisher`, `uxRestoreStatePublisher`
  - callback hooks (`onPageDidFinish`, download callbacks, etc.)

**Must NOT be accessed externally (implementation details)**
- Raw `WKWebView` storage: callers must not retain/configure/delegate-manage a `WKWebView` outside of the store.
- Internal controllers and state (`navigationController`, KVO observations, tasks, `isInvalidated`, etc.).
- WebKit delegate methods implemented by TabWebStore extensions (they are part of the WebKit integration, not a contract for higher layers).

### `SafariLikeCoreKit.TabRegistry`

**Who calls it**
- SafariLikeKit runtime: Tab activation/budgeting/eviction.
- SafariLikeCoreKit internal: store creation and process termination recovery.

**Stable contract (intended cross-layer API)**
- Store access and lifecycle
  - `store(for:paneID:role:)`
  - `activatedStore(for:paneID:role:protectedTabIDs:)`
  - `existingStore(for:)`
  - `remove(tabID:)` / `removeAll()` / `shutdown()`
- WebView lifecycle controls
  - `activateWebView(tabID:protectedTabIDs:)`
  - `deactivateWebView(tabID:mode:)`
  - `discardWebView(tabID:)`
- Budget/policy knobs
  - `setActivationSuppressed(_:)`
  - `handleMemoryPressure(protectedTabIDs:mode:)`

**Must NOT be accessed externally**
- Internal storage (`stores`, `lru`, `activeWebViewsLRU`, per-pane pool dictionaries).
- Direct manipulation of the store map or LRU.

### `SafariLikeKit.SceneRuntimeContext`

**Who calls it**
- SafariLikeKit UI layer: as an `@EnvironmentObject` / injected context.
- SafariLikeKit runtime: `TabManager`, `BrowserChromeState`, lifecycle routing.

**Stable contract (intended cross-layer API)**
- Scene-owned registries/pools (read-only)
  - `tabRegistry`, `privateTabRegistry`
  - `webViewPool`, `privateWebViewPool`
  - `uiState`
- Lifecycle
  - `shutdownAndReleaseWebViews()`
  - `setAppIsActive(_:)`
- Runtime event routing
  - `handleBrowserRuntimeEvent(_:viewModel:tabManager:)`
  - `requestReconcile(tabID:viewModel:tabManager:reason:)`
- Attachment read-only API
  - `currentAttachmentStatus()`
  - `attachmentStatusPublisher()`

**Must NOT be accessed externally**
- Internal attachment coordinator wiring and watchdog details.
- Assumptions about `TabWebStore` internal state; only the stable TabWebStore contract is allowed.

### `SafariLikeKit.AttachmentCoordinator`

**Who calls it**
- Only the scene runtime (`SceneRuntimeContext`).

**Stable contract (internal to SafariLikeKit)**
- Tracking
  - `startTrackingIfNeeded(tabID:store:io:)`
  - `stopTracking(tabID:)`
- Event inputs
  - `onRootViewAppeared(initialTabRequiresWebView:io:)`
  - `onTabActivated(tabRequiresWebView:io:)`
  - `onWebViewAttached(io:)`
  - `onWebViewDetached(tabRequiresWebView:io:)`
  - `requestReconcile(tabID:io:reason:)`
- Teardown
  - `shutdown()`

**Must NOT be accessed externally**
- UI must never call into this directly; it is a runtime coordinator.

### `SafariLikeKit.RenderPolicyManager`

**Who calls it**
- SafariLikeKit SwiftUI views (`@StateObject`) and renderer wiring.

**Stable contract (internal to SafariLikeKit)**
- `activate(_:)` / `deactivate(_:)`
- `activeContexts` (read-only published state)

**Must NOT be accessed externally**
- `contextByID` map contents and any assumptions about `WebContext` lifetime.

## 2–3) TabWebStore contract hardening + extension cleanup

Changes applied:
- `TabWebStore.webView` is no longer exposed cross-module; other modules must use `TabWebStore.webViewHandle?.webView`.
- Promoted stable APIs:
  - `updateRestoreState(currentURL:lastKnownTitle:)` is now public.
  - `discardWebView()` is now public (delegates to internal implementation).
- Removed duplicated cleanup work in `invalidate()` (redundant second `invalidateWebViewCore()` call).

Extensions remain behavior-grouping only; state continues to live on the main `TabWebStore` class.

## 4) Cross-module safety

- Other modules are now compile-fenced away from TabWebStore’s raw `WKWebView` storage.
- The supported cross-module WebKit access point is `WebViewHandle` (weak reference, main-actor).

## 5) Compile fence check (intent)

After the code changes, `SafariLikeKit` should compile without reaching into CoreKit implementation details like `TabWebStore.webView`.

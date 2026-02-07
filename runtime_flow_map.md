# Runtime Flow Map (App → SafariLikeKit → CoreKit → WKWebView)

Date: 2569-02-03

## Primary Call Path (Real Classes)

### 1) App boots a scene
- **App layer** creates and boots a per-scene composition root:
  - `App/AppBrowserSessionController.swift` (`AppCompositionRoot`, `SceneCompositionRoot`)
  - `App/AppRootView.swift` renders UI and calls `sceneRoot.registerLifecycleIfNeeded(...)`.

### 2) App injects the per-scene runtime boundary
- App obtains the scene’s runtime boundary from the lifecycle coordinator:
  - `AppLifecycleCoordinator.shared.sceneRuntimeContext(for: SceneID)`
- UI uses that context:
  - `SafariLikeBrowserView(session:context:...)` (SafariLikeKit UI facade)
  - SwiftUI injects it as an `@EnvironmentObject` in views such as `BrowserPaneView`.

### 3) SceneRuntimeContext routes runtime signals (no WebKit ownership)
- `SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift`
  - owns per-scene objects: `tabRegistry`, `privateTabRegistry`, `webViewPool`, `privateWebViewPool`, `AttachmentCoordinator`, UI state.
  - routes lifecycle/visibility signals into `AttachmentCoordinator`.

### 4) TabManager requests activation via TabRuntime
- `SafariLikeKit/Runtime/TabRuntime/TabRuntime.swift`
  - `activate(protectedTabIDs:)` → `registry.activatedStore(for:paneID:role:protectedTabIDs:)`

### 5) TabRegistry is the activation gate (budget enforcement)
- `SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift`
  - `activatedStore(...)`:
    - optional `activationSuppressed` prevents WKWebView activation (overview/snapshot-only modes)
    - enforces max concurrent views (LRU eviction)
    - selects **pool by pane**
    - calls `store.activate(using: pool)`

### 6) TabWebStore creates/owns the tab’s WKWebView
- `SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift`
  - `activate(using:)`:
    - chooses a pool (currently `pool ?? .shared` fallback)
    - computes a `WebContextRoute` via `WebContextRouter.shared.routeContext(...)`
    - fetches/creates a `WebContext` via `WebContextManager.shared.context(...)`
    - acquires a `WKWebView` via `pool.acquireWebView(for:tabID,context:)`
    - creates a `WebViewHandle` for UI embedding

### 7) WebViewPool tracks budgeting and leases
- `SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift`
  - The pool tracks “live” web views and enforces `maxLiveWebViews`.
  - Current migration mode:
    - `acquireWebView(for:context:)` **adopts** `context.webView` (WebContext-created WKWebView).

### 8) WKWebView construction sites (current)
WKWebView is constructed in multiple places:
- `SafariLikeCoreKit/WebKit/Context/WebContext.swift`
  - `self.webView = WKWebView(frame: .zero, configuration: self.configuration)`
- `SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift` and `SafariLikeKit/Core/Session/BrowserSceneSession.swift`
  - both create pools with `makeWebView: { WKWebView(frame: .zero, configuration: config) }`
- `SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift`
  - default `makeWebView` closure constructs a WKWebView

Safari-grade expectation: construction should be centralized behind a single factory path.

---

## Bypass / Alternate Activation Paths (Must be Eliminated for Safari-Grade)

### A) Pool fallback to global shared
- `TabRegistry.webViewPool(for:)` falls back to `.shared` when a pane has no registered pool.
- `TabWebStore.activate(using pool: WebViewPool? = nil)` falls back to `.shared`.
- `TabWebStore.deactivate(...)` and `invalidate()` fall back to `attachedWebViewPool ?? .shared`.

Impact:
- A missing scene/pane registration becomes a silent global cross-scene “escape hatch”.

### B) Activation without going through TabRegistry
- Any direct call site using `TabWebStore.activate(...)` or `ensureWebViewAttached()` can bypass `TabRegistry` budget enforcement.
- The codebase *mostly* routes activation via `TabRuntime` → `TabRegistry.activatedStore(...)`, but the APIs still exist and accept unsafe defaults.

### C) Global singletons in the WebKit routing chain
- `WebContextRouter.shared` and `WebContextManager.shared` are process-global.
- Even if they key by `windowID`, they can become cross-scene footguns unless teardown is strict and enforced.

---

## UI Embedding Path (Where WebKit meets SwiftUI)

- UI uses `WebViewHandle` (weak access) instead of owning WKWebView.
- `SafariLikeKit/Platform/Web/WebView.swift`:
  - attaches/detaches the WKWebView into a UIKit container
  - performs deterministic re-configuration each update
  - emits best-effort readiness signals

This is appropriate **only if** it never triggers activation/budget decisions itself.

---

## Recommended “Single Highway” (Target Design)

Target invariant:
- **Only** `TabRegistry.activatedStore(...)` is allowed to result in WKWebView creation/activation.

Enforcement knobs:
- Remove `.shared` fallbacks.
- Make pool registration required (precondition on missing pool).
- Make `TabWebStore.activate(using:)` require a non-nil pool and keep it internal to CoreKit.
- Consolidate WKWebView construction into `WebViewPool.borrow(...)` (or a dedicated factory) instead of `WebContext` constructing it.

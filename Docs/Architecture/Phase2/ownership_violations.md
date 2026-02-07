# Phase 2 — Ownership Violations (Safari-like)

This document lists ownership violations discovered during the Phase 2 audit.

## Violation categories

1. **App-scope singleton retains scene/tab state** (e.g. dictionaries keyed by `sceneID`/`tabID`, `WKWebView` retention, per-window closures).
2. **UI (SwiftUI View) constructs or owns runtime services** instead of a composition root.
3. **Duplicate owners**: the same responsibility is “owned” by two objects (e.g. both create/manage a pool/registry).
4. **Cross-scene leakage risk**: scene-specific state stored in process-wide registries or caches.

## Findings

| Location | Issue | Why it’s a violation | Minimal structural fix (no behavior change) |
| --- | --- | --- | --- |
| `SafariLikeCoreKit/Engine/EngineController.swift` | `EngineController.shared` holds per-tab mappings (e.g. `activeContextByTabID`) | App-scope singleton retaining tab state breaks per-tab ownership and cross-window isolation | Move tabID→context tracking behind `TabRegistry` / `SceneRuntimeContext`; keep `EngineController` app-scope but stateless w.r.t tab dictionaries |
| `SafariLikeCoreKit/WebKit/Context/WebContextManager.swift` | `WebContextManager.shared` stores `contexts: [Key: WebContext]` keyed by window/pane/tab | Scene/tab state stored in a process-wide singleton | Make `WebContextManager` scene-owned (constructed by `SceneRuntimeContext`) and inject it where needed; provide a compatibility shim only during migration |
| `SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift` | `WebViewPool.shared` and global pool table | Process-wide pool tracking can enable WebView reuse across scenes | Remove/avoid `shared` for runtime; ensure per-scene pools are constructed in scene root/session and passed explicitly |
| `SafariLikeKit/Lifecycle/LifecycleCoordinator.swift` | `LifecycleCoordinator.shared` stores per-scene `scenesByID` and window registries | App-scope singleton retaining scene sessions/tab managers is a direct “singleton stores scene state” violation | Convert to an instance owned by `AppCompositionRoot`; pass to scene roots; remove `.shared` access from SwiftUI Views |
| `SafariLikeKit/Runtime/Lifecycle/AppLifecycleCoordinator.swift` | `AppLifecycleCoordinator.shared` owns a `SceneRuntimeRegistry` of per-scene contexts | Singleton retains scene runtime contexts; scene lifetime should be bounded by scene root | Make an instance owned by `AppCompositionRoot`; expose `SceneRuntimeRegistry` via DI; no static `shared` |
| `SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift` + `SafariLikeKit/Core/Session/BrowserSceneSession.swift` + `SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift` | Duplicate ownership/backfilling of per-scene pools | The scene session already constructs + registers pools; the scene runtime context may backfill pools again if missing, obscuring who the owner is | Make pool creation a single responsibility of the scene root/session; make `SceneRuntimeContext` only *capture* pools (and assert if missing) |
| `App/AppRootView.swift` | SwiftUI lifecycle hooks call into `.shared` coordinators | The view layer is acting as the lifecycle orchestrator (and uses global state) | Route lifecycle events through scene root-owned coordinators; keep Views dumb (call methods on injected objects) |
| `BrowserCore/Core/Session/BrowserSessionCenter.swift` | Singleton provides per-mode session stores (not per window) | Multi-window apps should avoid conflating per-window state into process-wide stores | Prefer per-window stores created by factories (e.g. `CoreStoreFactory.makeWindowSessionStore`); deprecate / stop using global store for window sessions |

## Non-violations (explicitly acceptable)

These are app-scope singletons/services that appear not to retain scene/tab state and are generally acceptable in the Safari-like model:

- `SafariLikeCoreKit/Policy/PolicyCenter.shared` (policy registry)
- `SafariLikeCoreKit/WebKit/WebKitWarmup.shared` (warmup; no scene/tab state)
- `BrowserCore/Persistence/SiteHeuristicsStore.shared` (site-keyed cache)

> Note: even “acceptable” app-scope singletons should avoid capturing scene-owned objects in closures (e.g. observers/customizers) unless there is explicit scene teardown that unregisters them.

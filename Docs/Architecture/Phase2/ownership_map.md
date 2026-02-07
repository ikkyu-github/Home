# Phase 2 — Ownership Map (Safari-like)

This document assigns each major runtime type exactly one ownership scope and identifies its expected owner and lifetime.

## Scopes

- **App-scope**: Process-wide services/policy/persistence. Must not retain scene- or tab-specific runtime state (WKWebView instances, per-window registries, per-tab mappings).
- **Scene-scope**: Per `UIScene` / window runtime state and registries. Created when a scene connects; released on scene disconnect.
- **Tab-scope**: Per tab state including the WebView lifecycle and per-tab controllers. Created when a tab is created/opened; released when closed/invalidated.

## Composition roots (expected creation points)

- **AppCompositionRoot** (App-scope): created once by the app entry point; owns app-wide services and factories.
- **SceneCompositionRoot** (Scene-scope): created once per SwiftUI scene/window; owns the scene session and scene runtime context.

Current code already has both roots; Phase 2 is about tightening the wiring so that these roots (not singletons and not SwiftUI Views) are the primary owners.

## Ownership map (major runtime types)

| Type | Module | Location | Scope | Owner (constructs / holds) | Lifetime |
| --- | --- | --- | --- | --- | --- |
| `AppCompositionRoot` | App | `App/AppBrowserSessionController.swift` | App | `SafariPadCloneApp` creates once | app launch → termination |
| `SceneCompositionRoot` | App | `App/AppBrowserSessionController.swift` | Scene | created per SwiftUI scene/window | scene connect → disconnect |
| `AppBrowserSessionController` | App | `App/AppBrowserSessionController.swift` | App | created by `SafariPadCloneApp` | app launch → termination |
| `SafariLikeFactory` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SafariLikeFactory.swift` | App | referenced by app/scene roots | app launch → termination |
| `BrowserSceneSession` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserSceneSession.swift` | Scene | constructed by `SafariLikeFactory.makeSceneSession` from scene root | scene connect → disconnect |
| `SplitBrowserViewModel` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift` | Scene | owned by `BrowserSceneSession` | scene connect → disconnect |
| `BrowserChromeState` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/BrowserChromeState.swift` | Scene | owned by `BrowserSceneSession` / `SplitBrowserViewModel` | scene connect → disconnect |
| `TabManager` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/TabManager/TabManager.swift` | Scene | owned by scene runtime/lifecycle wiring | scene connect → disconnect |
| `SceneRuntimeContext` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeContext.swift` | Scene | should be owned by scene root (today fetched from app singleton) | scene connect → disconnect |
| `SceneUIState` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneUIState.swift` | Scene | owned by `SceneRuntimeContext` | scene connect → disconnect |
| `AttachmentCoordinator` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/AttachmentCoordinator.swift` | Scene | owned by `SceneRuntimeContext` | scene connect → disconnect |
| `WatchdogController` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/WatchdogController.swift` | Scene | owned by `SceneRuntimeContext` | scene connect → disconnect |
| `SceneRuntimeRegistry` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/SceneRuntimeRegistry.swift` | App | should be owned by app root (today owned via singleton) | app launch → termination |
| `AppLifecycleCoordinator` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Lifecycle/AppLifecycleCoordinator.swift` | App | should be owned by app root (today `shared`) | app launch → termination |
| `LifecycleCoordinator` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Lifecycle/LifecycleCoordinator.swift` | App | should be owned by app root (today `shared`) | app launch → termination |
| `TabRegistry` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabRegistry.swift` | Scene | owned by `SceneRuntimeContext` / `BrowserSceneSession` | scene connect → disconnect |
| `TabWebStore` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift` | Tab | owned by `TabRegistry` | tab open → tab close/invalidated |
| `WindowSession` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WindowSession/WindowSession.swift` | Scene | owned by `BrowserSceneSession` | scene connect → disconnect |
| `WindowSessionCoordinator` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WindowSession/WindowSessionCoordinator.swift` | Scene | owned by `BrowserSceneSession` | scene connect → disconnect |
| `BrowserStateCoordinator` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WindowSession/BrowserStateCoordinator.swift` | Scene | owned by `WindowSessionCoordinator` | scene connect → disconnect |
| `PaneContext` | SafariLikeKit | `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/SplitPane/PaneContext.swift` | Scene | constructed by `BrowserSceneSession` | scene connect → disconnect |
| `WebViewPool` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift` | Scene | should be owned by `SceneRuntimeContext` (avoid `shared`) | scene connect → disconnect |
| `EngineController` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift` | App | process-wide WebKit coordination; must not own per-tab state | app launch → termination |
| `WebContextManager` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContextManager.swift` | Scene | currently `shared` but stores per-window/pane/tab contexts; should be scene-owned | scene connect → disconnect |
| `PolicyCenter` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Policy/PolicyCenter.swift` | App | global policy registry + observers | app launch → termination |
| `WebKitWarmup` | SafariLikeCoreKit | `RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/WebKitWarmup.swift` | App | warmup helper; no scene/tab state | app launch → termination |
| `BrowserSessionCenter` | BrowserCore | `RuntimePackages/BrowserCore/Sources/BrowserCore/Core/Session/BrowserSessionCenter.swift` | App | app-wide persistence store access | app launch → termination |
| `SiteHeuristicsStore` | BrowserCore | `RuntimePackages/BrowserCore/Sources/BrowserCore/Persistence/SiteHeuristicsStore.swift` | App | app-wide heuristics cache | app launch → termination |

## Notes / clarifications

- **Tab-scoped WebKit objects** (e.g. a tab’s `WKWebView`) should be reachable only via tab-owned objects (`TabWebStore` and its controllers) and released on tab close.
- **Scene registries** (`TabRegistry`, per-scene pools, per-scene attachment coordinators) should be created by the Scene composition root or by `BrowserSceneSession` and torn down on scene disconnect.
- **App-scope singletons are not inherently forbidden**, but they must not contain scene/tab dictionaries (or closures) that retain scene-owned objects.

# Singleton Audit (Scene Isolation)

Goal: prevent cross-scene leaks in multi-window by ensuring **any state keyed by windowID / sceneID / tabID** is **scene-scoped** (owned by `SceneRuntimeContext`) or otherwise injected.

## Refactored (no longer process-global)

- `SafariLikeKit.Diagnostics.NavigationPolicyOverlayModel`
  - Now instantiated per scene and accessed via `SceneRuntimeContext.navigationPolicyOverlayModel`.
- `SafariLikeKit.Diagnostics.PerformanceOverlayModel`
  - Now instantiated per scene and accessed via `SceneRuntimeContext.performanceOverlayModel`.
  - WebView/attachment timing recorders are routed via injected closures.
- `SafariLikeKit.Core.Session.BrowserSceneSessionRegistry`
  - No longer provides a process-wide `.shared`.
  - Callers should own sessions per scene/window and retain them for the scene lifetime.

## Process-wide singletons (allowed with guardrails)

These remain process-wide because they do **not** track per-scene/tab identity, or they represent a deliberate process-wide service boundary.

- `BrowserCore.Persistence.SiteHeuristicsStore.shared`
  - Domain store keyed by site/URL, intentionally shared across scenes.
- `SafariLikeCoreKit.Diagnostics.NetworkStatusService.shared`
  - Process-wide network snapshot service.
- `SafariLikeCoreKit.Policy.PolicyCenter.shared`
  - Process-wide policy evaluation/registration.
- `SafariLikeCoreKit.WebKit.WebKitWarmup.shared`
  - Process-wide WebKit warmup control.

## Known follow-ups

- `SafariLikeCoreKit.Engine.EngineController.shared`
  - Process-wide by design, but internally tracks per-tab state (`tabID` maps). If multi-scene tab IDs are not guaranteed unique, this needs further scoping/partitioning.
- `SafariLikeKit.Lifecycle.LifecycleCoordinator.shared` / `SafariLikeKit.Runtime.Lifecycle.AppLifecycleCoordinator.shared`
  - Process-wide orchestrators that track per-scene entries. Consider future dependency injection if you want *zero* global scene registries.

# PR-02 Plan — Ownership Fixes (Safari-like)

This plan is **structural only**: change wiring/ownership, not behavior.

## Goals

- Enforce exactly-one-owner semantics for major runtime services.
- Keep the Safari-like scope model:
  - App-scope: policy/persistence/process WebKit coordination.
  - Scene-scope: registries, pools, per-window runtime context.
  - Tab-scope: per-tab WebView + per-tab controllers.
- Preserve Phase 1 layering constraints (no new forbidden module edges).
- No new singletons or global mutable runtime state.

## Proposed commits

1. **Docs: Phase 2 ownership artifacts**
   - Add/update:
     - `Docs/Architecture/Phase2/ownership_map.md`
     - `Docs/Architecture/Phase2/ownership_violations.md`
     - `Docs/Architecture/Phase2/PR-02-plan.md`

2. **App-owned lifecycle coordinators (remove `.shared` usage at call sites)**
   - Create instances of `AppLifecycleCoordinator` and `LifecycleCoordinator` in `AppCompositionRoot`.
   - Pass instances into `SceneCompositionRoot` (store as properties).
   - Update app/scene wiring to stop calling `LifecycleCoordinator.shared` / `AppLifecycleCoordinator.shared` directly.

3. **Scene-owned runtime registry (bound to composition root)**
   - Make `SceneRuntimeRegistry` a dependency owned by `AppCompositionRoot`.
   - Ensure `SceneRuntimeContext` objects are created/held by `SceneCompositionRoot` and released in `SceneCompositionRoot.shutdown()`.

4. **Remove app-scope retention of scene sessions/tab managers**
   - Refactor `LifecycleCoordinator` so it does not store `SceneEntry` objects containing `BrowserSceneSession`, view models, or `TabManager`.
   - If global coordination is needed, keep only lightweight, scene-id keyed weak references or registration tokens that do not retain the scene runtime.

5. **Make WebKit context tracking scene-owned**
   - Replace `WebContextManager.shared` usage with a scene-owned instance (owned by `SceneRuntimeContext`).
   - Plumb the instance through `TabRegistry` / `TabWebStore` as needed.
   - Add explicit teardown calls (`tearDownWindow(windowID:)`) from scene shutdown.

6. **Remove tab/scene dictionaries from app-scope engine singletons**
   - Make `EngineController` app-scope and stateless w.r.t tab-specific dictionaries.
   - Move tabID→context ownership to scene/tab scope (`TabRegistry` / `SceneRuntimeContext`).

7. **Eliminate `WebViewPool.shared` from runtime paths**
   - Ensure all code paths use per-scene pools from `SceneRuntimeContext`.
   - If `WebViewPool.shared` remains for legacy APIs, mark it deprecated and gate it to debug/testing only.

8. **Guardrails (debug-only)**
   - Add lightweight assertions/logging to detect:
     - use-after-shutdown (scene context accessed after `shutdown()`)
     - cross-scene resource reuse (WebViewPool created for one windowID used by another)

## Verification

- Run the existing build tasks:
  - `xcodebuild webOS (quick build)`
  - `swift test BrowserCore`
- Add/adjust any unit tests only if they already exist in the touched packages.

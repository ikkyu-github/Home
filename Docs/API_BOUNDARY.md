# Public API Boundary

This doc defines what *App code* is allowed to touch, and what must remain internal.

## Canonical flow (must not be bypassed)

`SceneRuntimeContext → TabRegistry → WebViewPool → WebContext`

Intent:
- WebKit object ownership and lifecycle lives in the engine/runtime layer.
- UI may *observe* state and *request* actions, but must not directly mutate WebKit runtime internals.

## Allowed (App target)

- Import:
  - `SafariLikeKit`
  - `SafariLikeContracts`
  - Apple frameworks (`SwiftUI`, `UIKit`, `Foundation`, ...)

- Use:
  - `SafariLikeBrowserView` (facade entrypoint)
  - `SceneRuntimeContext` as an `@EnvironmentObject` for scene-scoped overlays/diagnostics models
  - Reexported policy/model types exposed by `SafariLikeKit` (e.g. `PolicyCenter`, `PolicyDecision`, ...)

## Forbidden (App target)

- Imports:
  - `SafariLikeCoreKit`
  - `BrowserCore`
  - `SafariLikeUXKit`

- Direct access to CoreKit runtime handles (must not be reachable through the `SafariLikeKit` facade):
  - tab registries (`TabRegistry`)
  - web view pools (`WebViewPool`)
  - web context routing/management (`WebContextManager`, `WebContextRouter`)
  - engine lifecycle entrypoints intended for internal orchestration

## Notes

- SafariLikeKit may depend on CoreKit/BrowserCore internally. The key rule is: **SafariLikeKit must not leak engine handles through its public API**.
- If the App needs additional safe functionality, add a SafariLikeKit facade method/type rather than exposing CoreKit internals.

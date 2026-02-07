# UI ↔ Runtime Boundary (Intent API)

## Rule
UI/App code must **emit intents** and must not reach into runtime internals.

- UI emits: `BrowserRuntimeIntent`
- Runtime entrypoint: `BrowserSceneSession.send(intent:)`
- Runtime decides/mutates internal state (TabManager, registries, attachment/activation).

## Why
This keeps the WebView lifecycle and policy enforcement **single-writer** and makes layering violations hard to reintroduce.

## Allowed from App/UI
- Import: `SafariLikeKit` (and `SafariLikeContracts` if needed)
- Hold a `BrowserSceneSession` (or `BrowserRuntimeIntentDispatching`) and call:
  - `session.send(intent: ...)`
  - `session.openExternalURL(_:)` / `persistSessionNow()` / `invalidateSession()` (legacy convenience wrappers)

SwiftUI environment wiring:
- Use `EnvironmentValues.browserRuntime` (intent dispatcher)
- Do not use `browserTabManager`

## Forbidden
- Accessing `TabManager`, `TabRegistry`, `SceneRuntimeContext`, or any attach/activate APIs from App/UI.
- Using `.tabManager` or `BrowserTabManaging` from App code.

## Enforcement
Run:
- `Dev/Tools/Scripts/architecture_check.sh`

It fails CI if App imports forbidden modules, references runtime internals, or if attachment/activation calls leak outside runtime internals.

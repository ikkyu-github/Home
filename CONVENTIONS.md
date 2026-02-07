# Conventions (Anti-bloat Guardrails)

This file is intentionally short and actionable. If a rule can’t be enforced or reviewed quickly, it doesn’t belong here.

## Folder roles (where-to-put-what)

- `App/`
  - App entrypoints, composition roots, scene/window wiring, and user settings.
  - Must remain thin: render UI + route events to `SafariLikeKit`.

- `App/Views/`
  - SwiftUI views only.
  - No business/policy decisions, no WebKit lifecycle decisions.

- `App/UI/Debug/`
  - DEBUG-only UI overlays, test hooks, and developer diagnostics.
  - Must be wrapped in `#if DEBUG` at the type/file level.

- `RuntimePackages/SafariLikeContracts/`
  - SSOT types, protocols, constants.
  - Must not import UI frameworks or `WebKit`.

- `RuntimePackages/BrowserCore/`
  - Domain models + persistence.
  - Must not import `WebKit` / `UIKit` / `SwiftUI`.

- `RuntimePackages/SafariLikeUXKit/`
  - UI policy and orchestration that is WebKit-agnostic.
  - Must not import `WebKit`.

- `RuntimePackages/SafariLikeCoreKit/`
  - Runtime/engine policy, WebKit adapters, pooling, activation, budgeting.

- `RuntimePackages/SafariLikeKit/`
  - Public facade + composition/wiring.
  - Owns adapters/coordinators between UI and runtime.

## Naming

- Types: `UpperCamelCase`
- Protocols: `*Providing`, `*Managing`, `*Routing` (prefer intent over nouns)
- Adapters/impl: `FooImpl` only when it’s clearly an implementation of `Foo` protocol
- Files:
  - One primary type per file.
  - Extensions: `Type+Feature.swift` (e.g. `TabWebStore+Downloads.swift`).

## State & ownership

- Scene/tab/window scoped state must be instance-owned and injected.
- Avoid `static let shared` in core layers unless it is a true constant/stateless helper.
- If you must keep a singleton temporarily, document why and add a follow-up issue.

## Debug separation

- Debug/test hooks belong under `App/UI/Debug/`.
- Debug-only settings/defaults must be guarded with `#if DEBUG`.
- Never make Release behavior depend on a debug-only keypath unless explicitly intended.

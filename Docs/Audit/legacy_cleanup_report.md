# Legacy Cleanup Report (PR-03)

This report tracks deprecated/legacy code discovered during PR-03 and what action was taken.

## Completed (removed)

### SafariLikeKit

- Removed `BrowserPane.swift`
  - Location: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Runtime/BrowserPane.swift`
  - Status: File contained only imports + a deprecation comment (no symbols).
  - Rationale: Unused legacy placeholder; safe to delete.

- Removed `WebViewProviding.swift`
  - Location: `RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Runtime/WebViewProviding.swift`
  - Status: File contained only imports + a deprecation comment (no symbols).
  - Rationale: Unused legacy placeholder; safe to delete.

### SafariLikeUXKit

- Removed `ChromeUIState`
  - Location: `RuntimePackages/SafariLikeUXKit/Sources/SafariLikeUXKit/StateMachines/ChromeUIState.swift`
  - Status: Deprecated `ObservableObject` implementation; no call sites found in `RuntimePackages/**`.
  - Rationale: Dead legacy UI state holder; safe to delete.

## Identified (pending)

The following items were discovered by repo-wide scans (e.g. `@available(*, deprecated, ...)`, “legacy”, “compatibility shim”), but are not changed yet in this diff batch.

- Deprecated session registry types in SafariLikeKit (`SceneSessionRegistry`, `BrowserWindowSession`) – verify live references and decide delete vs. isolate.
- Deprecated WebKit compatibility extensions (e.g. `WKWebView+Shared.swift`) – verify references and remove if unused.
- Deprecated protocols (e.g. `ThumbnailProviding`) – confirm whether still needed as a compatibility surface.

## Guardrails

- No new global mutable state introduced.
- Intended to be behavior- and UI-neutral.

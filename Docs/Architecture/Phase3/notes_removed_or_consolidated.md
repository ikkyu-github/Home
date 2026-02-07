# Phase 3 — Notes on Removed / Consolidated Logic

## Consolidations

- TabWebStore WebKit access: migrated cross-module callers from `TabWebStore.webView` to `TabWebStore.webViewHandle?.webView`.
  - Rationale: `WebViewHandle` is the supported contract; it avoids encouraging long-lived retention or delegate mutation outside `TabWebStore`.

## Removed duplication

- `TabWebStore.invalidate()` no longer calls `invalidateWebViewCore()` twice.
  - The first call already performs delegate/script teardown; the second call was redundant.

## Removed dead/unstable checks

- `SceneRuntimeContext.updateWebViewPerformanceTiers` removed the branch that attempted to reattach when `store.webView != nil && store.webViewHandle == nil`.
  - With the current CoreKit lifecycle (`deactivate()` nils both), this condition is effectively unreachable.
  - Keeping it also conflicts with contract hardening, since `webView` is no longer a cross-module API.

## Test updates

- `SafariLikeCoreKitTests/TabWebStoreLifecycleTests` updated to use `webViewHandle?.webView` instead of `webView`.

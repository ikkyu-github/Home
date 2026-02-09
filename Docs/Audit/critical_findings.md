# Critical Findings (Safari-Grade Risks)

Date: 2569-02-03

This report lists high-risk architecture issues that can cause:
- cross-scene leakage
- non-deterministic activation
- budgeting regressions
- hidden global state coupling

Each finding includes why it matters and where it is observed.

---

## CF-01: `.shared` WebViewPool fallback breaks per-scene ownership
**Risk:** High

Observed:
- `SafariLikeCoreKit/WebKit/Pool/WebViewPool.shared` exists.
- `SafariLikeCoreKit/Runtime/Tab/TabRegistry.webViewPool(for:)` uses `webViewPoolByPaneID[paneID] ?? .shared`.
- `SafariLikeCoreKit/Runtime/Tab/TabWebStore.activate(using pool: WebViewPool? = nil)` uses `pool ?? .shared`.

Why this is dangerous:
- Any missing registration or wrong paneID silently routes WebKit ownership into a global pool.
- This is exactly the kind of “works most of the time” coupling that becomes impossible to debug under multi-window stress.

Safari-grade expectation:
- Missing per-scene pool registration should be a loud failure (debug precondition) and/or should be impossible by API design.

---

## CF-02: WKWebView construction is not fully centralized
**Risk:** High

Observed WKWebView construction sites:
- `SafariLikeCoreKit/WebKit/Context/WebContext` constructs WKWebView directly.
- Multiple `makeWebView` closures also construct WKWebView.

Why this is dangerous:
- Multiple construction sites make it easy to accidentally bypass configuration policy, plugin installation order, or per-scene process pool constraints.
- It also makes deterministic budgeting harder: the pool is sometimes tracking a WebView it did not create.

Safari-grade expectation:
- One authoritative factory path for construction, tied to the owning pool and the registry.

---

## CF-03: Global mutable WebKit context cache (window-scoped values stored globally)
**Risk:** High

Observed:
- `WebContextManager.shared` stores:
  - `contexts` keyed by (windowID, paneID, tabID, privacy)
  - `configurationCustomizersByWindowID` keyed by windowID

Why this is dangerous:
- Even with keys, this is process-global mutable state.
- If teardown is incomplete, old windows can retain window-scoped objects via configuration customizers.

What must be true for safety:
- Window teardown must call `tearDownWindow(windowID:)` reliably.
- `configurationCustomizersByWindowID` must be cleared for every window.

Safari-grade expectation:
- Prefer per-scene ownership of context caches, or strict lifecycle enforcement with automated tests.

---

## CF-04: Global singleton routers in the activation chain
**Risk:** Medium-High

Observed:
- `WebContextRouter.shared` depends on `SiteHeuristicsStore.shared` by default.

Why this is dangerous:
- It pulls site heuristics and routing decisions through process-global state.
- Under multi-window concurrency, any shared mutable store must be proven thread-safe and deterministic.

Safari-grade expectation:
- If routing depends on heuristics, either:
  - treat the heuristics store as immutable snapshot input, or
  - scope it per scene/window, or
  - make the shared store explicitly actor-isolated and audited.

---

## CF-05: App-level singleton stores scene runtime contexts
**Risk:** Medium

Observed:
- `AppLifecycleCoordinator.shared` holds a mutable `SceneRuntimeRegistry`.

Why this is dangerous:
- A singleton itself is not always wrong, but it becomes a nexus for “just reach for the shared coordinator” patterns.
- It’s easy for features to leak per-scene state into app-global singletons.

Safari-grade expectation:
- Central registry may exist, but APIs should be narrow and strongly typed to prevent state leakage.

---

## CF-06: Debug-only global trackers that observe WebView attachment
**Risk:** Medium

Observed:
- `SafariLikeKit/Platform/Web/WebViewAttachmentTracker.shared` holds a set of attached WKWebView identifiers.

Why this is dangerous:
- Even if DEBUG-only assertions are fine, global state can produce false positives/negatives under multi-window transitions if it’s not keyed by scene/window.

Safari-grade expectation:
- Track budgets via the same registry/pool authority, not via UI attachment counting.

---

## CF-07: Legacy/migration shims remain in WebViewPool and TabWebStore
**Risk:** Medium

Observed:
- `WebViewPool.acquireWebView(for:context:)` “adopts” `context.webView`.
- Multiple “legacy API” methods and comments indicate the system is mid-migration.

Why this is dangerous:
- Migration shims are where bypasses hide.
- They increase surface area for accidental use from higher layers.

Safari-grade expectation:
- Either fully finish the migration or fence off legacy APIs with restricted visibility and tests.

---

## Summary: Highest Priority Fixes
1) Remove `.shared` fallbacks (pool + store).
2) Centralize WKWebView creation behind a single factory path.
3) Make window teardown clear global caches/customizers deterministically.
4) Add automated checks that prevent reintroducing bypasses.

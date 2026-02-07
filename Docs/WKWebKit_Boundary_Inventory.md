# WebKit Boundary Inventory

Generated: 2026-02-06

## Summary (current repo state)

- `WKWebView(` matches: **2** (both in WebViewPool.swift; one is a comment, one is the constructor)
- `WKWebViewConfiguration(` matches: **1** (centralized in WebConfigurationProvider)
- `WKProcessPool` matches: **1** (comment-only; iOS 15+ deprecation note)
- `WKWebsiteDataStore` matches: **22** (mix of policy docs + service implementation)
- `.configuration` matches: **26** (mix of `webView.configuration` usage + non-WebKit app configuration plumbing)

## `WKWebView(` occurrences

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L58) — Comment documenting the “all constructors route here” rule.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L62) — The **only** `WKWebView` constructor call (`WKWebView(frame:configuration:)`).

## `WKWebViewConfiguration(` occurrences

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift#L28) — `WebConfigurationProvider.makeWebViewConfiguration(profile:)` builds the configuration (single source of truth).

## `WKProcessPool` occurrences

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L26) — Comment noting `WKProcessPool` is deprecated on iOS 15+ and intentionally not used.

## `WKWebsiteDataStore` occurrences

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift#L169) — Doc: private profile uses `WKWebsiteDataStore.nonPersistent()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Engine/EngineController.swift#L170) — Doc: regular profile uses `WKWebsiteDataStore.default()`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L9) — Doc: all data store/record access is on `MainActor`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L16) — Uses `WKWebsiteDataStore.allWebsiteDataTypes()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L41) — Uses `WKWebsiteDataStore.allWebsiteDataTypes()` when request types are empty.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L71) — Uses `WKWebsiteDataStore.allWebsiteDataTypes()` for supported types.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L77) — `resolveDataStore(...)` returns a `WKWebsiteDataStore`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L80) — Regular profile maps to `WKWebsiteDataStore.default()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L94) — Helper arg typed as `WKWebsiteDataStore`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L106) — Helper arg typed as `WKWebsiteDataStore`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L119) — Helper arg typed as `WKWebsiteDataStore`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift#L23) — Doc: private profile uses `WKWebsiteDataStore.nonPersistent()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebProcessPoolProvider.swift#L24) — Doc: regular profile uses `WKWebsiteDataStore.default()`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift#L18) — API takes a `WKWebsiteDataStore` and infers profile.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift#L20) — Compares against `WKWebsiteDataStore.nonPersistent()` to infer profile.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift#L28) — Doc: regular profile uses `WKWebsiteDataStore.default()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift#L29) — Doc: private profile uses `WKWebsiteDataStore.nonPersistent()`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewConfigurationFactory.swift#L42) — API arg typed as `WKWebsiteDataStore`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift#L30) — Doc: browsing profile determines underlying `WKWebsiteDataStore` via configuration factory.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L32) — Stored property typed as `WKWebsiteDataStore`.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift#L8) — Doc: persistent mode uses `WKWebsiteDataStore.default()`.
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/SplitFeatureFlags.swift#L9) — Doc: non-persistent mode uses `WKWebsiteDataStore.nonPersistent()` per window/scene.

## `.configuration` occurrences

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/UserScripts/TabWebStore+UserScripts.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/UserScripts/TabWebStore+UserScripts.swift#L22) — Reads `webView.configuration.userContentController` to install scripts.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/WebKitPolicyBridge.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/WebKitPolicyBridge.swift#L76) — Reads `webView.configuration.mediaTypesRequiringUserActionForPlayback` (autoplay policy).
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/WebKitPolicyBridge.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/WebKitPolicyBridge.swift#L78) — Mutates `webView.configuration` via `WebViewMediaPolicy.applyAutoplayPolicy`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L55) — Assigns `self.configuration` from initializer arg.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L65) — Applies privacy mode to `self.configuration`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L66) — Sets `self.configuration.websiteDataStore`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L67) — Sets `self.configuration.userContentController`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L68) — Runs `configurationCustomizer` on `self.configuration`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Context/WebContext.swift#L72) — Applies `WebViewMediaPolicy` to `self.configuration`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L257) — Captures `context.configuration` when ensuring/creating a WebView.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/WebKit/Pool/WebViewPool.swift#L265) — Recreate path captures `context.configuration` for factory closure.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift#L114) — Reads `webView.configuration.userContentController` for safe handler cleanup.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift#L247) — Applies per-site preferences to `webView.configuration`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/TabWebStore/Controllers/TabNavigationController.swift#L322) — Removes content rule lists from `webView.configuration.userContentController`.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Runtime/Tab/TabWebStore.swift#L434) — Applies autoplay policy to `context.configuration` pre-construction.

- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewHandle.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewHandle.swift#L119) — Exposes `webView?.configuration`.
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewHandle.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Platform/Web/WebViewHandle.swift#L150) — Accesses `webView?.configuration.userContentController` in helper.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsCollector.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Metrics/MetricsCollector.swift#L35) — Non-WebKit: stores actor configuration.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift#L246) — Non-WebKit: reads `environment.configuration`.
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel.swift#L281) — Non-WebKit: assigns `self.configuration`.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowser/SplitBrowserStateGlue.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowser/SplitBrowserStateGlue.swift#L168) — Applies per-site preferences to `webView.configuration`.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserSceneSession.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/Session/BrowserSceneSession.swift#L49) — Non-WebKit: reads `environment.configuration`.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift#L150) — Non-WebKit: assigns `self.configuration`.

- [RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabWebStoreLifecycleTests.swift](RuntimePackages/SafariLikeCoreKit/Tests/SafariLikeCoreKitTests/TabWebStoreLifecycleTests.swift#L239) — Reads `webView.configuration.userContentController` in lifecycle test.

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift#L42) — Non-WebKit: stores `SafariLikeConfiguration`.
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserRootView.swift#L27) — Non-WebKit: stores `SafariLikeConfiguration`.

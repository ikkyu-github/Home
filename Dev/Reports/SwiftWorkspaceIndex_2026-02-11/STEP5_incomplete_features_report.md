# Incomplete Features (TODO/FIXME + Parity Notes)

Ranking basis is keyword matching only; otherwise marked UNVERIFIED.

## Critical (10)

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift#L23): // TODO(PARITY-005): Handle all BrowserLayoutMode cases explicitly; avoid relying on @unknown default fallback (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/NavigationService.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/NavigationService.swift#L7): // TODO: NavigationService is the gateway between Domain logic and WebView layer
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetrics.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetrics.swift#L10): // TODO(PARITY-003): Audit rotation/resize stabilization (rapid flips, split resizes); ensure stableInsets/size commits never drift or lag across epochs (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift#L332): // TODO(PARITY-002): Verify keyboard-lift rect/bands match viewport contract; unify any WebView inset/interactive-region assumptions to snapshot.viewport (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift#L38): // TODO(PARITY-001): Anchor landscape content to snapshot.viewport.contentRect consistently; avoid any implicit rect derivation (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift#L176): // TODO(PARITY-002): Verify keyboard-lift/viewport contract integration for landscape WebView insets and interactive bands (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift#L91): // TODO(PARITY-004): Harmonize SplitBrowserRootView chromeStyle + related policy resolution with the SSOT pipeline used by BrowserView/BrowserLayoutSpine (see Docs/BrowserUILayoutParity.md)
- [webOSUITests/TabChromeUITests.swift](webOSUITests/TabChromeUITests.swift#L5): // TODO: Launch iPad landscape, enter address editing, assert tab strip/header
- [webOSUITests/TabChromeUITests.swift](webOSUITests/TabChromeUITests.swift#L8): // TODO: Simulate swipe chrome, assert tab overview
- [webOSUITests/TabChromeUITests.swift](webOSUITests/TabChromeUITests.swift#L11): // TODO: Tap chrome buttons, assert WKWebView does not intercept

## Medium (1)

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/BrowserChromeState+Contracts.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/BrowserChromeState+Contracts.swift#L12): isVisible: !chromeSnapshot.isCollapsed, // TODO: map collapsed state to isVisible

## Cleanup (11)

- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Config/BrowserEnvironment.swift#L92): // TODO: Update preview to use proper mock objects once WebsitePreferencesStore
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Preview/Store+Preview.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Preview/Store+Preview.swift#L42): // TODO: WebsitePreferencesStore preview moved to SafariLikeUIKit
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/BrowserChromeState+Contracts.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/BrowserChromeState+Contracts.swift#L14): // TODO: isInOverview, isOmniboxOverlayVisible, isAddressFocused should be handled in View layer or UXKit
- [RuntimePackages/SafariLikeKit/Tests/StaticSharedGateTests.swift](RuntimePackages/SafariLikeKit/Tests/StaticSharedGateTests.swift#L5): // TODO: Assert no static let shared except whitelist
- [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift#L39): /// - TODO: Plugin system for extensible providers (bookmarks, history, downloads)
- [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift#L40): /// - TODO: Multi-window support - allow multiple factory instances per window/scene
- [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift#L41): /// - TODO: Custom storage backends (not just JSONFileStoreActor)
- [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift#L134): // MARK: - TODO: Plugin System
- [RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift](RuntimePackages/SafariLikeUIKit/Sources/SafariLikeUIKit/Composition/SafariLikeUIKitFactory.swift#L171): // MARK: - TODO: Multi-Window Support
- [RuntimePackages/SafariLikeUXKit/Tests/AddressBarStateMachineTests.swift](RuntimePackages/SafariLikeUXKit/Tests/AddressBarStateMachineTests.swift#L6): // TODO: Assert AddressBar transitions
- [RuntimePackages/SafariLikeUXKit/Tests/ChromeStateMachineTests.swift](RuntimePackages/SafariLikeUXKit/Tests/ChromeStateMachineTests.swift#L6): // TODO: Assert Chrome transitions

## Parity Notes (code occurrences) (11)

- [RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/SiteSettings/SiteKey.swift](RuntimePackages/SafariLikeContracts/Sources/SafariLikeContracts/SiteSettings/SiteKey.swift#L55): // Known parity gap vs real eTLD+1 for multi-part TLDs (e.g. co.uk).
- [RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift](RuntimePackages/SafariLikeCoreKit/Sources/SafariLikeCoreKit/Stores/WebKitWebsiteDataService.swift#L82): // Parity gap: EngineController currently creates distinct nonPersistent stores per WebView.
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Core/RelatedPresentationPolicy.swift#L23): // TODO(PARITY-005): Handle all BrowserLayoutMode cases explicitly; avoid relying on @unknown default fallback (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Diagnostics/SafariLikeParityReport.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Diagnostics/SafariLikeParityReport.swift#L9): /// DEBUG-only parity report that can be triggered without UI.
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Diagnostics/SafariLikeParityReport.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Diagnostics/SafariLikeParityReport.swift#L25): lines.append("=== Safari Parity Report (DEBUG) ===")
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetrics.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/Runtime/Scene/SceneMetrics.swift#L10): // TODO(PARITY-003): Audit rotation/resize stabilization (rapid flips, split resizes); ensure stableInsets/size commits never drift or lag across epochs (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/BrowserPaneView.swift#L332): // TODO(PARITY-002): Verify keyboard-lift rect/bands match viewport contract; unify any WebView inset/interactive-region assumptions to snapshot.viewport (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift#L38): // TODO(PARITY-001): Anchor landscape content to snapshot.viewport.contentRect consistently; avoid any implicit rect derivation (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/LandscapeBrowserLayout.swift#L176): // TODO(PARITY-002): Verify keyboard-lift/viewport contract integration for landscape WebView insets and interactive bands (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/UI/Layout/SplitBrowserRootView.swift#L91): // TODO(PARITY-004): Harmonize SplitBrowserRootView chromeStyle + related policy resolution with the SSOT pipeline used by BrowserView/BrowserLayoutSpine (see Docs/BrowserUILayoutParity.md)
- [RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel+Persistence.swift](RuntimePackages/SafariLikeKit/Sources/SafariLikeKit/ViewModel/SplitBrowserViewModel+Persistence.swift#L17): // Private mode parity: clear all private session state on shutdown.

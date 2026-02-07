// ARCH-AUDIT(2026-01-22): Scene-session facade. Keep SafariLikeKit UI-free (no UIKit imports); UI glue belongs in SafariLikeUIKit/App.
import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
import Combine
/// Public facade for managing a single browser session within a scene.
///
/// `BrowserSceneSession` is the **exclusive public entrypoint** for accessing SafariLikeKit's browser
/// functionality. It provides a clean contract between your App and the framework's internal
/// ViewModels, Stores, and Runtime components.
///
/// ## Contract
/// - **Do NOT** import `SplitBrowserViewModel`, `BrowserEnvironment`, or any `Runtime/*` types directly.
/// - **Do NOT** access `.viewModel` or `.chrome` from outside SafariLikeKit.
/// - **Always** use public facade methods for App lifecycle integration:
///   - ``openExternalURL(_:)`` - Handle deep links and external URLs
///   - ``persistSessionNow()`` - Save session before backgrounding
///   - ``invalidateSession()`` - Clean up when scene disconnects
///
/// ## Typical Usage
/// ```swift
/// // Create via SafariLikeUIKitHost or SafariLikeFactory
/// let (hostVC, session) = SafariLikeUIKitHost.makeHostingController(
///     sceneID: "main",
///     initialURL: "https://example.com",
///     configuration: .default
/// )
/// 
/// // Use public methods only
/// session.openExternalURL(deepLinkURL)
/// session.persistSessionNow()
/// session.invalidateSession()
/// ```
///
/// ## Internal Architecture (not for public use)
/// - Owns `viewModel` (SplitBrowserViewModel) for UI state and navigation
/// - Owns `chrome` (BrowserChromeState) for downloads, thumbnails, downloads
/// - Both are internal; use public methods to interact
@MainActor
public final class BrowserSceneSession {
    // Session persistence is owned by BrowserCore.BrowserSessionStore.
    let viewModel: SplitBrowserViewModel
    /// Do not use `unowned` here: if teardown order changes, this will crash. Use strong reference.
    let chrome: BrowserChromeState
    let sceneID: String
    var windowLayoutAutosaveCancellables = Set<AnyCancellable>()
    init(environment: BrowserEnvironment) {
        self.sceneID = environment.sceneID
        let configuration = environment.configuration
        let contentBlockerManager: (any ContentBlockingProviding)? = configuration.contentBlockerEnabled ? ContentBlockerManager() : nil
        let searchURL = URL(string: configuration.searchEngineURL)
        let fallback = SafariLikeContracts.DefaultURLs.googleHomepage
        let engineURL = searchURL ?? fallback
        let windowIdentity = environment.windowIdentityString
        // Session stores (regular/private) are window-scoped and owned by the scene session.
        let normalSessionStore = environment.sessionStore
        let privateSessionStore = BrowserSessionStore(persistence: .memory)
        let normalMaxAlive = configuration.resolvedMaxAliveWebViews(for: .regular)
        let privateMaxAlive = configuration.resolvedMaxAliveWebViews(for: .private)
        let maxConcurrentOverride = configuration.resolvedMaxConcurrentActiveWebViewsOverride()

        let normalTabRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowIdentity,
            defaultHomeURLString: configuration.defaultHomeURLString,
            searchEngineURL: engineURL,
            contentBlockerManager: contentBlockerManager,
            websitePreferencesProvider: environment.websitePreferencesStore,
            siteSettingsStore: environment.siteSettingsStore,
            formFillPolicyEngine: environment.formFillPolicyEngine,
            userScriptStore: environment.userScriptStore,
            browsingProfile: .regular,
            maxAliveWebViewsOverride: normalMaxAlive,
            maxConcurrentActiveWebViewsOverride: maxConcurrentOverride
        )
        // Safari-style: a single pool per scene/profile, shared across panes,
        // so maxAlive/maxLive budgeting is scene-wide (not per pane).
        let normalPool = WebViewPool(
            label: "\(windowIdentity).regular",
            maxLiveWebViews: normalMaxAlive,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
        normalTabRegistry.registerWebViewPool(normalPool, forPane: PaneID.primary.rawValue)
        normalTabRegistry.registerWebViewPool(normalPool, forPane: PaneID.secondary.rawValue)
        let privateTabRegistry = SafariLikeCoreKit.TabRegistry(
            windowID: windowIdentity,
            defaultHomeURLString: configuration.defaultHomeURLString,
            searchEngineURL: engineURL,
            contentBlockerManager: contentBlockerManager,
            websitePreferencesProvider: environment.websitePreferencesStore,
            siteSettingsStore: nil,
            formFillPolicyEngine: environment.formFillPolicyEngine,
            userScriptStore: environment.userScriptStore,
            browsingProfile: .private,
            maxAliveWebViewsOverride: privateMaxAlive,
            maxConcurrentActiveWebViewsOverride: maxConcurrentOverride
        )
        let privatePool = WebViewPool(
            label: "\(windowIdentity).private",
            maxLiveWebViews: privateMaxAlive,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .private)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
        privateTabRegistry.registerWebViewPool(privatePool, forPane: PaneID.primary.rawValue)
        privateTabRegistry.registerWebViewPool(privatePool, forPane: PaneID.secondary.rawValue)
        let normalPaneContexts: [PaneID: PaneContext] = [
            .primary: PaneContext(paneID: .primary, webViewPool: normalPool),
            .secondary: PaneContext(paneID: .secondary, webViewPool: normalPool)
        ]
        let privatePaneContexts: [PaneID: PaneContext] = [
            .primary: PaneContext(paneID: .primary, webViewPool: privatePool),
            .secondary: PaneContext(paneID: .secondary, webViewPool: privatePool)
        ]
        let windowSession = SafariLikeCoreKit.WindowSession(
            sessionStore: normalSessionStore,
            sidebarMode: .hidden,
            browsingProfile: .regular
        )
        // Keep library persistence routing in sync with the window session browsing profile.
        environment.libraryProfileBox.profile = windowSession.browsingProfile
        windowSession.$browsingProfile
            .receive(on: RunLoop.main)
            .sink { profile in
                environment.libraryProfileBox.profile = profile
            }
            .store(in: &windowLayoutAutosaveCancellables)
        let windowCoordinator = SafariLikeCoreKit.WindowSessionCoordinator(
            windowSession: windowSession,
            regular: .init(
                sessionStore: normalSessionStore,
                browserState: SafariLikeCoreKit.BrowserStateCoordinator(tabRegistry: normalTabRegistry)
            ),
            private: .init(
                sessionStore: privateSessionStore,
                browserState: SafariLikeCoreKit.BrowserStateCoordinator(tabRegistry: privateTabRegistry)
            )
        )
        let viewModel = SplitBrowserViewModel(
            environment: environment,
            windowSession: windowSession,
            windowCoordinator: windowCoordinator,
            normalSessionStore: normalSessionStore,
            privateSessionStore: privateSessionStore,
            normalTabRegistry: normalTabRegistry,
            privateTabRegistry: privateTabRegistry,
            normalPaneContexts: normalPaneContexts,
            privatePaneContexts: privatePaneContexts,
            contentBlockerManager: contentBlockerManager,
            initialURL: nil
        )
        self.viewModel = viewModel
        self.chrome = viewModel.chrome
        installWindowLayoutAutosave()
        installUIStateAutosave()
    }
}

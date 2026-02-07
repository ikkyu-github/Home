import Foundation
import BrowserCore
import SafariLikeContracts

/// Per-scene runtime isolation boundary (CoreKit).
///
/// This type owns all scene/window-scoped CoreKit state that must never be stored
/// in process-wide singletons.
@MainActor
public final class SceneRuntimeContext {
    public enum ActivationState: Sendable, Equatable {
        case connected
        case foreground
        case background
        case disconnected
    }

    public struct BudgetState: Sendable, Equatable {
        public var maxLiveWebViewsRegular: Int
        public var maxLiveWebViewsPrivate: Int
        public var maxConcurrentActiveWebViewsRegular: Int
        public var maxConcurrentActiveWebViewsPrivate: Int

        public init(
            maxLiveWebViewsRegular: Int,
            maxLiveWebViewsPrivate: Int,
            maxConcurrentActiveWebViewsRegular: Int,
            maxConcurrentActiveWebViewsPrivate: Int
        ) {
            self.maxLiveWebViewsRegular = maxLiveWebViewsRegular
            self.maxLiveWebViewsPrivate = maxLiveWebViewsPrivate
            self.maxConcurrentActiveWebViewsRegular = maxConcurrentActiveWebViewsRegular
            self.maxConcurrentActiveWebViewsPrivate = maxConcurrentActiveWebViewsPrivate
        }
    }

    /// Scene identifier (typically `UISceneSession.persistentIdentifier`).
    public let sceneIdentifier: String

    /// Window identifier used for WebContext scoping.
    public let windowID: String

    /// Scene-local WebView ownership/activation registry (regular browsing profile).
    public let tabRegistry: TabRegistry

    /// Scene-local WebView ownership/activation registry (private browsing profile).
    public let privateTabRegistry: TabRegistry

    /// Scene-local `WKWebView` pool used by the regular profile registries.
    public let webViewPool: WebViewPool

    /// Scene-local `WKWebView` pool used by the private profile registries.
    public let privateWebViewPool: WebViewPool

    /// Scene-local WebContext manager (must not be process-global).
    public let webContextManager: WebContextManager

    /// Scene-local WebContext router.
    public let webContextRouter: WebContextRouter

    /// Scene-local activation tracking (foreground/background/disconnect).
    public private(set) var activationState: ActivationState = .connected

    /// Scene-owned website data policy (normal/private).
    public let websiteDataPolicy: WebsiteDataPolicySet

    /// Scene-local budgets (mirrors the per-pool maxLiveWebViews caps).
    public private(set) var budgetState: BudgetState

    /// CoreKit single-authority state machine for tab/page lifecycle.
    public private(set) var tabPageLifecycle: TabPageLifecycleStateMachine = TabPageLifecycleStateMachine()

    public init(
        sceneIdentifier: String,
        windowID: String,
        tabRegistry: TabRegistry,
        privateTabRegistry: TabRegistry,
        siteHeuristicsStore: SiteHeuristicsStore,
        websiteDataPolicy: WebsiteDataPolicySet = .default,
        budget: WebViewBudget? = nil
    ) {
        self.sceneIdentifier = sceneIdentifier
        self.windowID = windowID
        self.tabRegistry = tabRegistry
        self.privateTabRegistry = privateTabRegistry
        self.websiteDataPolicy = websiteDataPolicy

        // Scene-scoped WebContext services.
        let webContextManager = WebContextManager()
        let webContextRouter = WebContextRouter(store: siteHeuristicsStore)
        self.webContextManager = webContextManager
        self.webContextRouter = webContextRouter
        self.tabRegistry.setWebContextServices(manager: webContextManager, router: webContextRouter)
        self.privateTabRegistry.setWebContextServices(manager: webContextManager, router: webContextRouter)

        // Capture (or backfill) explicitly registered per-scene pools.
        let primaryPane = PaneID.primary.rawValue
        let secondaryPane = PaneID.secondary.rawValue

        let resolvedRegularPool: WebViewPool = {
            if let pool = tabRegistry.registeredWebViewPool(forPane: primaryPane) {
                return pool
            }

            #if DEBUG
            assertionFailure("[SceneRuntimeContext] Missing registered WebViewPool for regular profile. scene=\(sceneIdentifier)")
            #endif

            Diagnostics.logError(
                "[SceneRuntimeContext] Missing registered WebViewPool (regular); creating fallback pool. scene=\(sceneIdentifier)",
                subsystem: .runtime,
                category: "WebViewBudget"
            )

            let created = WebViewPool(
                label: "\(sceneIdentifier).regular",
                maxLiveWebViews: BrowserPolicy.TabRegistry.maxAliveWebViews(for: .regular),
                makeWebView: {
                    let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
                    return WebViewPool.makeWebView(configuration: config)
                }
            )

            tabRegistry.registerWebViewPool(created, forPane: primaryPane)
            tabRegistry.registerWebViewPool(created, forPane: secondaryPane)
            return created
        }()

        let resolvedPrivatePool: WebViewPool = {
            if let pool = privateTabRegistry.registeredWebViewPool(forPane: primaryPane) {
                return pool
            }

            #if DEBUG
            assertionFailure("[SceneRuntimeContext] Missing registered WebViewPool for private profile. scene=\(sceneIdentifier)")
            #endif

            Diagnostics.logError(
                "[SceneRuntimeContext] Missing registered WebViewPool (private); creating fallback pool. scene=\(sceneIdentifier)",
                subsystem: .runtime,
                category: "WebViewBudget"
            )

            let created = WebViewPool(
                label: "\(sceneIdentifier).private",
                maxLiveWebViews: BrowserPolicy.TabRegistry.maxAliveWebViews(for: .private),
                makeWebView: {
                    let config = EngineController.shared.makeWebViewConfiguration(profile: .private)
                    return WebViewPool.makeWebView(configuration: config)
                }
            )

            privateTabRegistry.registerWebViewPool(created, forPane: primaryPane)
            privateTabRegistry.registerWebViewPool(created, forPane: secondaryPane)
            return created
        }()

        self.webViewPool = resolvedRegularPool
        self.privateWebViewPool = resolvedPrivatePool

        if let budget {
            // Apply stricter caps. SceneRuntimeContext is the single owner of scene budgets.
            let regularMaxLive = max(1, min(BrowserPolicy.TabRegistry.maxAliveWebViews(for: .regular), budget.regular.maxLiveWebViews))
            let privateMaxLive = max(1, min(BrowserPolicy.TabRegistry.maxAliveWebViews(for: .private), budget.privateProfile.maxLiveWebViews))

            let regularMaxConcurrent = max(1, min(BrowserPolicy.maxConcurrentViews, min(regularMaxLive, budget.regular.maxConcurrentActiveWebViews)))
            let privateMaxConcurrent = max(1, min(BrowserPolicy.maxConcurrentViews, min(privateMaxLive, budget.privateProfile.maxConcurrentActiveWebViews)))

            resolvedRegularPool.maxLiveWebViews = regularMaxLive
            resolvedPrivatePool.maxLiveWebViews = privateMaxLive
            tabRegistry.applyWebViewBudgetOverrides(maxAliveWebViews: regularMaxLive, maxConcurrentActiveWebViews: regularMaxConcurrent)
            privateTabRegistry.applyWebViewBudgetOverrides(maxAliveWebViews: privateMaxLive, maxConcurrentActiveWebViews: privateMaxConcurrent)
        }

        self.budgetState = BudgetState(
            maxLiveWebViewsRegular: resolvedRegularPool.maxLiveWebViews,
            maxLiveWebViewsPrivate: resolvedPrivatePool.maxLiveWebViews,
            maxConcurrentActiveWebViewsRegular: tabRegistry.debugMaxConcurrentViewsLimit,
            maxConcurrentActiveWebViewsPrivate: privateTabRegistry.debugMaxConcurrentViewsLimit
        )
    }

    public func setActivationState(_ state: ActivationState) {
        activationState = state
    }

    public func updateBudgetsFromPools() {
        budgetState = BudgetState(
            maxLiveWebViewsRegular: webViewPool.maxLiveWebViews,
            maxLiveWebViewsPrivate: privateWebViewPool.maxLiveWebViews,
            maxConcurrentActiveWebViewsRegular: tabRegistry.debugMaxConcurrentViewsLimit,
            maxConcurrentActiveWebViewsPrivate: privateTabRegistry.debugMaxConcurrentViewsLimit
        )
    }

    /// Receives UI/runtime lifecycle events and maps them into CoreKit intents.
    ///
    /// This is the single authority for deciding `suspended`/`snapshotOnly`/`liveAttached`.
    public func handleTabPageLifecycleEvent(
        _ event: TabPageLifecycleStateMachine.Event
    ) -> [TabPageLifecycleStateMachine.Effect] {
        tabPageLifecycle.handle(event: event, sceneID: sceneIdentifier)
    }

    public func tabPageLifecycleState(
        tabID: UUID
    ) -> TabPageLifecycleStateMachine.State {
        tabPageLifecycle.state(tabID: tabID)
    }

    /// Best-effort teardown for scene disconnect.
    ///
    /// - Cancels per-window WebContext customizers.
    /// - Aggressively shuts down per-scene registries.
    public func shutdownAndReleaseWebViews() {
        webContextManager.tearDownWindow(windowID: windowID)

        Task { @MainActor [tabRegistry, privateTabRegistry] in
            await tabRegistry.shutdown()
            await privateTabRegistry.shutdown()
        }
    }
}

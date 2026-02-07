import Foundation
import WebKit
import BrowserCore

@MainActor
public final class TabRegistry {
    // MARK: - Required stored properties
    private let windowID: String
    private let defaultHomeURLString: String
    private var searchEngineURL: URL
    private let browsingProfile: BrowsingProfile
    private let debugLogEnabled: Bool
    private let contentBlockerManager: (any ContentBlockingProviding)?
    private weak var websitePreferencesProvider: (any WebsitePreferencesProviding)?
    private let siteSettingsStore: SiteSettingsStore?
    private let formFillPolicyEngine: FormFillPolicyEngine?
    private let userScriptStore: UserScriptStore?

    /// Optional stricter upper bound for max-alive stores/webviews.
    ///
    /// Policy contract:
    /// - CoreKit remains the source of truth (BrowserPolicy).
    /// - UI/config layers may provide a stricter cap, but may not exceed BrowserPolicy.
    private var maxAliveWebViewsOverride: Int?

    /// Optional stricter upper bound for concurrently active WebViews.
    ///
    /// Policy contract:
    /// - May be stricter than CoreKit policy, but must not exceed `BrowserPolicy.maxConcurrentViews`.
    private var maxConcurrentActiveWebViewsOverride: Int?

    private var maxAliveWebViewsLimit: Int {
        let policyMax = BrowserPolicy.TabRegistry.maxAliveWebViews(for: browsingProfile)
        guard let override = maxAliveWebViewsOverride else { return policyMax }
        let normalized = max(BrowserPolicy.TabRegistry.minimumAliveWebViews, override)
        return min(policyMax, normalized)
    }

    private var maxConcurrentViewsLimit: Int {
        let policyMax = max(1, BrowserPolicy.maxConcurrentViews)
        let requested = maxConcurrentActiveWebViewsOverride.map { max(1, $0) } ?? policyMax
        let capped = min(policyMax, requested)
        return min(maxAliveWebViewsLimit, capped)
    }

    /// Apply stricter budgeting at runtime (scene-owned wiring).
    ///
    /// This is intentionally a "tighten only" API: callers should not use it to increase budgets
    /// above existing policy/config without a deliberate review.
    @MainActor
    public func applyWebViewBudgetOverrides(
        maxAliveWebViews: Int?,
        maxConcurrentActiveWebViews: Int?
    ) {
        if let maxAliveWebViews {
            // Clamp to at least 1; the computed property will also enforce policy caps.
            self.maxAliveWebViewsOverride = max(1, maxAliveWebViews)
        }
        if let maxConcurrentActiveWebViews {
            self.maxConcurrentActiveWebViewsOverride = max(1, maxConcurrentActiveWebViews)
        }

        // Enforce updated caps best-effort without changing user-facing behavior.
        Task { @MainActor in
            await self.trimIfNeeded()
            await self.enforceMaxConcurrentViewsNow(protectedTabIDs: [])
        }
    }

    @MainActor
    private func enforceMaxConcurrentViewsNow(protectedTabIDs: Set<UUID>) async {
        let maxConcurrent = maxConcurrentViewsLimit
        if activeWebViewsLRU.count <= maxConcurrent { return }

        while activeWebViewsLRU.count > maxConcurrent {
            if let candidate = activeWebViewsLRU.reversed().first(where: { !protectedTabIDs.contains($0) }) {
                deactivateWebViewIfActive(tabID: candidate, mode: .warm)
                continue
            }
            // Everything is protected; stop rather than violating the protected contract.
            break
        }

        #if DEBUG
        if activeWebViewsLRU.count > maxConcurrent {
            assertionFailure(
                "[TabRegistry] enforceMaxConcurrentViewsNow failed. activeLRU=\(activeWebViewsLRU.count) max=\(maxConcurrent) windowID=\(windowID)"
            )
        }
        #endif
    }

    // MARK: - Runtime Stores
    /// Live stores keyed by tab id.
    private var stores: [UUID: TabWebStore] = [:]
    /// Simple LRU so we don't keep unlimited WKWebViews alive.
    /// Safari uses aggressive eviction; we keep a small pool.
    private var lru: [UUID] = []

    /// Global LRU for currently active (alive) `WKWebView` instances.
    ///
    /// Important: This is a *window-wide* budget. Split panes must respect the global cap
    /// (`BrowserPolicy.maxConcurrentViews`) rather than allowing up to the cap per pane.
    /// This list is separate from `lru` (store LRU) because stores can exist without an attached web view.
    private var activeWebViewsLRU: [UUID] = []

    /// Informational: which pane a currently-active tab is associated with.
    private var activePaneByTabID: [UUID: String] = [:]

    // MARK: - Per-pane WebView Pools

    /// Optional per-pane webview pools (e.g. primary vs secondary split-pane).
    ///
    /// Contract: Activation is gated and requires an explicitly registered pool.
    private var webViewPoolByPaneID: [String: WebViewPool] = [:]

    // MARK: - Scene-scoped WebContext services
    private var webContextManager: WebContextManager?
    private var webContextRouter: WebContextRouter?

    // Keep diagnostics lightweight; don't log-spam in production.
    private var didLogMissingWebContextServicesOnce: Bool = false

    // MARK: - Activation Suppression

    /// When true, `activatedStore(...)` will not create/attach new `WKWebView` instances.
    ///
    /// Used to guarantee that overview (and similar snapshot-only modes) never causes
    /// accidental WebView activation beyond the 2-view render budget.
    private var activationSuppressed: Bool = false

    // MARK: - Web Content Process Termination

    private var webContentTerminationObserverToken: UUID?

    /// Coalesced recovery tasks per tab to avoid overlapping recovery work.
    private var pendingWebContentRecoveryTaskByTabID: [UUID: Task<Void, Never>] = [:]

    // Diagnostics counters are intentionally lightweight and safe to ship.
    // UI surfaces them only in DEBUG builds.
    public private(set) var debugWebContentTerminationCount: Int = 0
    public private(set) var debugLastWebContentTerminationTabID: UUID?
    public private(set) var debugLastWebContentTerminationAt: Date = .distantPast

    // MARK: - Init

    /// Designated initializer.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    public init(
        windowID: String,
        defaultHomeURLString: String,
        searchEngineURL: URL = DefaultURLs.SearchEngine.googleQuery,
        contentBlockerManager: (any ContentBlockingProviding)? = nil,
        websitePreferencesProvider: (any WebsitePreferencesProviding)? = nil,
        siteSettingsStore: SiteSettingsStore? = nil,
        formFillPolicyEngine: FormFillPolicyEngine? = nil,
        userScriptStore: UserScriptStore? = nil,
        browsingProfile: BrowsingProfile = .regular,
        debugLogEnabled: Bool = true,
        maxAliveWebViewsOverride: Int? = nil,
        maxConcurrentActiveWebViewsOverride: Int? = nil
    ) {
        self.windowID = windowID
        self.defaultHomeURLString = defaultHomeURLString
        self.searchEngineURL = searchEngineURL
        self.contentBlockerManager = contentBlockerManager
        self.websitePreferencesProvider = websitePreferencesProvider
        self.siteSettingsStore = siteSettingsStore
        self.formFillPolicyEngine = formFillPolicyEngine
        self.userScriptStore = userScriptStore
        self.browsingProfile = browsingProfile
        self.debugLogEnabled = debugLogEnabled
        self.maxAliveWebViewsOverride = maxAliveWebViewsOverride
        self.maxConcurrentActiveWebViewsOverride = maxConcurrentActiveWebViewsOverride

        // Hardening: if WebContent process dies (CARenderServer/device context failures, etc.),
        // higher layers must not rely on reload() only. Force store + WKWebView recreation.
        self.webContentTerminationObserverToken = EngineController.shared.addWebContentProcessTerminationObserver { [weak self] tabID in
            guard let self else { return }
            self.handleWebContentTermination(tabID: tabID)
        }

        // Safari-grade wiring: do not silently fall back to a default pool.
        // Owners (scene/runtime) must explicitly register pools for each pane.
    }

    /// Inject scene-scoped WebContext services.
    ///
    /// This eliminates process-wide caches keyed by window/tab, which break strict scene isolation.
    @MainActor
    public func setWebContextServices(manager: WebContextManager, router: WebContextRouter) {
        self.webContextManager = manager
        self.webContextRouter = router
        for store in stores.values {
            store.setWebContextServices(manager: manager, router: router)
        }
    }

    @MainActor
    private func ensureWebContextServicesAvailable() -> (manager: WebContextManager, router: WebContextRouter) {
        if let manager = webContextManager, let router = webContextRouter {
            return (manager: manager, router: router)
        }

        // Strict wiring contract: WebContext services are scene-local and must be injected
        // by SceneRuntimeContext. Do not fall back to global singletons here.
        #if DEBUG
        assertionFailure("[TabRegistry] Missing injected WebContext services at store creation time. SceneRuntimeContext must call setWebContextServices(manager:router:). windowID=\(windowID)")
        #endif
        if didLogMissingWebContextServicesOnce == false {
            didLogMissingWebContextServicesOnce = true
            Diagnostics.logError(
                "[TabRegistry] Missing injected WebContext services at store creation time. windowID=\(windowID)",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
        }
        preconditionFailure("[TabRegistry] Missing injected WebContext services. windowID=\(windowID)")
    }

    deinit {
        if let token = webContentTerminationObserverToken {
            // Deinit is not actor-isolated in Swift 6 mode; hop explicitly.
            Task { @MainActor in
                EngineController.shared.removeWebContentProcessTerminationObserver(token)
            }
        }
        // Do not await in deinit. Only clear dictionaries.
        stores.removeAll()
        lru.removeAll()
        activeWebViewsLRU.removeAll()
        activePaneByTabID.removeAll()
    }

    /// Async shutdown hook for owner to call before deinit.
    @MainActor
    public func shutdown() async {
        if let token = webContentTerminationObserverToken {
            EngineController.shared.removeWebContentProcessTerminationObserver(token)
            webContentTerminationObserverToken = nil
        }

        let removedStores = Array(stores.values)
        stores.removeAll()
        lru.removeAll()
        activeWebViewsLRU.removeAll()
        activePaneByTabID.removeAll()
        for store in removedStores {
            await store.invalidate()
        }
    }

    @MainActor
    private func handleWebContentTermination(tabID: UUID) {
        guard let store = stores[tabID] else { return }
        guard !store.isInvalidated else { return }

        debugWebContentTerminationCount += 1
        debugLastWebContentTerminationTabID = tabID
        debugLastWebContentTerminationAt = Date()

        // Capture best-effort last URL for deterministic reload.
        // Prefer the handle's effective URL, fall back to last known store state.
        let lastURLString: String? = {
            if let url = store.webViewHandle?.effectiveURL { return url.absoluteString }
            if let url = store.currentURL { return url.absoluteString }
            if let url = store.restoreState?.currentURL { return url.absoluteString }
            return nil
        }()

        // 1) Invalidate *only the WebView* (not the tab/store). This preserves observers and callbacks
        //    installed by higher layers (SafariLikeKit) while ensuring the broken WKWebView is discarded.
        discardWebView(tabID: tabID)

        // 2) Queue a pending load so the next activation deterministically reloads.
        //    This must happen after discard to ensure the load doesn't target a terminated WKWebView.
        if let lastURLString, lastURLString.isEmpty == false {
            store.performLoadResolvedURL(lastURLString)
        }

        // 3) If the app is active and activation isn't suppressed, re-activate immediately to recover.
        //    Coalesce recovery work to avoid repeated activations during crash loops.
        pendingWebContentRecoveryTaskByTabID[tabID]?.cancel()
        pendingWebContentRecoveryTaskByTabID[tabID] = Task { @MainActor [weak self, weak store] in
            guard let self, let store else { return }
            guard !Task.isCancelled else { return }
            guard !store.isInvalidated else { return }
            if self.activationSuppressed { return }

            let isAppActive: Bool = {
                if let isAppActiveClosure = store.isAppActiveClosure {
                    return isAppActiveClosure()
                }
                return true
            }()
            guard isAppActive else { return }

            // Force canonical activation path so a fresh WebView is acquired from the registered pool.
            _ = await self.activatedStore(
                for: tabID,
                paneID: store.paneID,
                role: store.role,
                protectedTabIDs: [tabID]
            )

            // Cleanup task bookkeeping.
            self.pendingWebContentRecoveryTaskByTabID[tabID] = nil
        }
    }

    // MARK: - Public API

    // MARK: Debug / Introspection

    /// Count of live `TabWebStore` instances currently held by the registry.
    /// Threading: Read on the main actor.
    @MainActor
    public var aliveStoresCount: Int {
        stores.count
    }

    /// Debug/introspection: the resolved max-alive budget for this registry.
    /// Threading: Read on the main actor.
    @MainActor
    public var debugMaxAliveWebViewsLimit: Int {
        maxAliveWebViewsLimit
    }

    /// Debug/introspection: the resolved max-concurrent-active budget for this registry.
    /// Threading: Read on the main actor.
    @MainActor
    public var debugMaxConcurrentViewsLimit: Int {
        maxConcurrentViewsLimit
    }

    /// Count of currently active (attached) webviews.
    /// Threading: Read on the main actor.
    @MainActor
    public var activeWebViewsCount: Int {
        // Prefer the authoritative list, but reconcile against actual stores.
        let authoritative = activeWebViewsLRU.count
        let computed = stores.values.reduce(into: 0) { partial, store in
            if store.webViewHandle != nil { partial += 1 }
        }
        return max(authoritative, computed)
    }

    /// Snapshot of active WebView LRU (most-recent first).
    /// Threading: Read on the main actor.
    @MainActor
    public func activeTabIDsLRUSnapshot() -> [UUID] {
        activeWebViewsLRU
    }

    /// Enables/disables new WebView activation through `activatedStore`.
    /// Threading: Call on the main actor.
    @MainActor
    public func setActivationSuppressed(_ suppressed: Bool) {
        activationSuppressed = suppressed
    }

    /// Aggressively drops non-protected WebViews on memory pressure.
    ///
    /// - Important: This does not remove stores; it only detaches WebViews.
    /// - Threading: Call on the main actor.
    @MainActor
    public func handleMemoryPressure(protectedTabIDs: Set<UUID>, mode: WebViewDetachMode = .cold) {
        // Include warm-cached WebViews (handle may be nil).
        let snapshot = Array(stores.keys)
        for tabID in snapshot where !protectedTabIDs.contains(tabID) {
            guard let store = stores[tabID], store.webView != nil else { continue }
            deactivateWebViewIfActive(tabID: tabID, mode: mode)
        }
    }

    /// Returns an already-created store if it is currently alive in the registry.
    /// Used by lightweight UI (like tab overview thumbnails)
    /// to avoid creating/evicting WKWebViews.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    public func existingStore(for tabID: UUID) -> TabWebStore? {
        stores[tabID]
    }

    /// Alive tab ids (current registry keys).
    ///
    /// Threading: Read on the main actor.
    @MainActor
    public var aliveTabIDs: [UUID] {
        Array(stores.keys)
    }

    /// Threading: Call on the main actor.
    @MainActor
    public func updateSearchEngineURL(_ url: URL) {
        searchEngineURL = url
        for store in stores.values {
            store.searchEngineURL = url
        }
    }

    /// Get or create a runtime store for a tab.
    ///
    /// Note: This does NOT activate a `WKWebView`. To enforce concurrent view limits,
    /// call `activatedStore(for:role:protectedTabIDs:)`.
    /// Threading: Call on the main actor.
    @MainActor
    public func store(
        for tabID: UUID,
        role: TabWebStore.Role
    ) async -> TabWebStore {
        await store(for: tabID, paneID: "primary", role: role)
    }

    /// Pane-aware overload.
    ///
    /// Note: This does NOT activate a `WKWebView`. To enforce concurrent view limits,
    /// call `activatedStore(for:paneID:role:protectedTabIDs:)`.
    /// Threading: Call on the main actor.
    @MainActor
    public func store(
        for tabID: UUID,
        paneID: String = "primary",
        role: TabWebStore.Role = .primary
    ) async -> TabWebStore {
        if let existing = stores[tabID] {
            touch(tabID)
            return existing
        }

        // Do not create WKWebView at launch. TabWebStore will create WKWebView lazily when activated.
        let configFactory = WebViewConfigurationFactory()
        let configuration = configFactory.makeConfiguration(profile: browsingProfile)

        let webContextServices = ensureWebContextServicesAvailable()
        let restoreStateStore = TabRestoreStateStore()
        let performanceTierProvider = TabPerformanceTierStore(performanceTier: .foreground)
        let created = TabWebStore(
            tabID: tabID,
            windowID: windowID,
            paneID: paneID,
            role: role,
            configuration: configuration,
            defaultHomeURLString: defaultHomeURLString,
            searchEngineURL: searchEngineURL,
            contentBlockerManager: contentBlockerManager,
            websitePreferencesProvider: websitePreferencesProvider,
            siteSettingsStore: siteSettingsStore,
            formFillPolicyEngine: formFillPolicyEngine,
            userScriptStore: userScriptStore,
            browsingProfile: browsingProfile,
            configFactory: configFactory,
            webContextManager: webContextServices.manager,
            webContextRouter: webContextServices.router,
            performanceTierProvider: performanceTierProvider,
            restoreStateStore: restoreStateStore,
            dependencies: .standard()
        )
        created.setActivationAllowedGate { [weak self] in
            // Do not allow store-level activation helpers to bypass global suppression.
            (self?.activationSuppressed == false)
        }
        #if DEBUG
        if debugLogEnabled {
            Diagnostics.logDebug(
                "[TabRegistry] CREATE WebView for tabID=\(tabID)",
                subsystem: .web,
                category: "TabRegistry"
            )
        }
        #endif
        stores[tabID] = created
        touch(tabID)
        await trimIfNeeded()
        return created
    }

    // MARK: - Removal

    @MainActor
    public func remove(tabID: UUID) async {
        let removed = stores.removeValue(forKey: tabID)
        lru.removeAll { $0 == tabID }
        activeWebViewsLRU.removeAll { $0 == tabID }
        activePaneByTabID.removeValue(forKey: tabID)
        #if DEBUG
        if debugLogEnabled {
            Diagnostics.logDebug(
                "[TabRegistry] EVICT WebView for tabID=\(tabID)",
                subsystem: .web,
                category: "TabRegistry"
            )
        }
        #endif
        if let removed = removed {
            await removed.invalidate()
        }
    }

    @MainActor
    public func removeAll() async {
        let removedStores = Array(stores.values)
        stores.removeAll()
        lru.removeAll()
        activeWebViewsLRU.removeAll()
        activePaneByTabID.removeAll()
        for store in removedStores {
            await store.invalidate()
        }
    }

    // MARK: - Policy-gated WebView Activation

    /// Ensures a `WKWebView` is alive for the given tab by activating its store.
    ///
    /// Policy:
    /// - Uses `BrowserPolicy.maxConcurrentViews` as the only source of truth.
    /// - If at capacity, it reuses/replaces by deactivating an existing (LRU) web view.
    @MainActor
    public func activatedStore(
        for tabID: UUID,
        role: TabWebStore.Role,
        protectedTabIDs: Set<UUID> = []
    ) async -> TabWebStore {
        await activatedStore(for: tabID, paneID: "primary", role: role, protectedTabIDs: protectedTabIDs)
    }

    /// Pane-aware overload.
    ///
    /// Ensures a `WKWebView` is alive for the given tab by activating its store.
    ///
    /// Policy:
    /// - Uses `BrowserPolicy.maxConcurrentViews` as the only source of truth.
    /// - If at capacity, it reuses/replaces by deactivating an existing (LRU) web view.
    @MainActor
    public func activatedStore(
        for tabID: UUID,
        paneID: String = "primary",
        role: TabWebStore.Role = .primary,
        protectedTabIDs: Set<UUID> = []
    ) async -> TabWebStore {
        let store = await self.store(for: tabID, paneID: paneID, role: role)

        CoreKitMetrics.recordTabActivationAttempt()

        // Guardrail: strict window/pane ownership and state invariants.
        // Prefer suppressing activation over creating an incorrectly keyed WebContext.
        guard TabLifecycleGuard.validateBeforeActivation(
            store: store,
            expectedWindowID: windowID,
            requestedPaneID: paneID
        ) else {
            CoreKitMetrics.recordTabActivationGuardRejected()
            return store
        }

        // Scene isolation hardening: registries should be wired with per-scene services.
        if webContextManager == nil || webContextRouter == nil {
            #if DEBUG
            assertionFailure("[TabRegistry] Missing injected WebContext services at activation time. SceneRuntimeContext must call setWebContextServices(manager:router:). windowID=\(windowID)")
            #endif
            if didLogMissingWebContextServicesOnce == false {
                didLogMissingWebContextServicesOnce = true
                Diagnostics.logError(
                    "[TabRegistry] Missing injected WebContext services at activation time. windowID=\(windowID)",
                    subsystem: .runtime,
                    category: "TabLifecycle"
                )
            }
        }

        // If already active, just refresh LRU.
        if store.webViewHandle != nil {
            touchActiveWebView(tabID, paneID: paneID)
            return store
        }

        if activationSuppressed {
            CoreKitMetrics.recordTabActivationSuppressed()
            #if DEBUG
            if debugLogEnabled {
                Diagnostics.logDebug(
                    "[TabRegistry] SUPPRESS activation tabID=\(tabID) paneID=\(paneID)",
                    subsystem: .web,
                    category: "TabRegistry"
                )
            }
            #endif
            return store
        }

        await enforceMaxConcurrentViewsBeforeActivating(
            activatingTabID: tabID,
            paneID: paneID,
            protectedTabIDs: protectedTabIDs
        )

        guard let pool = webViewPool(for: paneID) else {
            CoreKitMetrics.recordTabActivationMissingPoolSuppressed()
            #if DEBUG
            assertionFailure("[TabRegistry] Missing WebViewPool for paneID=\(paneID). Call registerWebViewPool(_:forPane:) during scene wiring.")
            #endif
            Diagnostics.logError(
                "[TabRegistry] SUPPRESS activation (missing WebViewPool) tabID=\(tabID) paneID=\(paneID)",
                subsystem: .web,
                category: "TabRegistry"
            )
            return store
        }
        var protected = protectedTabIDs
        protected.insert(tabID)
        pool.setProtectedTabIDs(protected)
        await pool.makeTabActive(tabID)

        await store.activate(using: pool)
        CoreKitMetrics.recordTabActivationSucceeded()
        // NOTE: Do not validate here; TabWebStore.activate already validates when activation actually creates a WebView.
        touchActiveWebView(tabID, paneID: paneID)

        #if DEBUG
        if activeWebViewsCount > maxConcurrentViewsLimit {
            assertionFailure(
                "[TabRegistry] active webviews exceeded budget. active=\(activeWebViewsCount) max=\(maxConcurrentViewsLimit) windowID=\(windowID) tabID=\(tabID)"
            )
        }
        #endif
        return store
    }

    /// Registers a `WebViewPool` for a specific pane.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    public func registerWebViewPool(_ pool: WebViewPool, forPane paneID: String) {
        webViewPoolByPaneID[paneID] = pool
        pool.budgetDelegate = self
    }

    /// Returns the `WebViewPool` registered for the given pane, if any.
    ///
    /// This does **not** fall back to any global/shared pool; it is intended for
    /// diagnostics and scene-scoped wiring where you need to confirm that
    /// each window/pane has an explicitly registered pool.
    @MainActor
    public func registeredWebViewPool(forPane paneID: String) -> WebViewPool? {
        webViewPoolByPaneID[paneID]
    }

    @MainActor
    private func webViewPool(for paneID: String) -> WebViewPool? {
        webViewPoolByPaneID[paneID]
    }

    // MARK: - WebView Discard (keep store)

    public enum WebViewDetachMode: Sendable {
        /// Detach the UI handle but keep the underlying `WKWebView` alive for fast reattach.
        case warm
        /// Detach and aggressively drop the `WKWebView` (reclaim memory).
        case cold
    }

    /// Deactivates/detaches the underlying `WKWebView` for a tab.
    ///
    /// This keeps the `TabWebStore` alive in the registry, preserving lightweight state
    /// and any externally managed snapshots/thumbnails.
    ///
    /// Threading: Call on the main actor.
    @MainActor
    public func deactivateWebView(tabID: UUID, mode: WebViewDetachMode = .warm) {
        deactivateWebViewIfActive(tabID: tabID, mode: mode)
    }

    /// Discard the WKWebView for a tab while keeping the store alive.
    ///
    /// This captures minimal restore state and transitions the tab into a discardable tier
    /// so large tab counts remain stable.
    @MainActor
    public func discardWebView(tabID: UUID) {
        guard let store = stores[tabID] else { return }
        store.discardWebView()
        activeWebViewsLRU.removeAll { $0 == tabID }
        activePaneByTabID.removeValue(forKey: tabID)
    }

    // MARK: - LRU Management

    @MainActor
    private func touch(_ id: UUID) {
        lru.removeAll { $0 == id }
        lru.insert(id, at: lru.startIndex)
    }

    @MainActor
    private func touchActiveWebView(_ id: UUID, paneID: String) {
        activeWebViewsLRU.removeAll { $0 == id }
        activeWebViewsLRU.insert(id, at: activeWebViewsLRU.startIndex)
        activePaneByTabID[id] = paneID
    }

    @MainActor
    private func deactivateWebViewIfActive(tabID: UUID, mode: WebViewDetachMode) {
        guard let store = stores[tabID] else { return }

        // If no WebView exists, just reconcile tracking.
        guard store.webView != nil else {
            activeWebViewsLRU.removeAll { $0 == tabID }
            activePaneByTabID.removeValue(forKey: tabID)
            return
        }

        switch mode {
        case .warm:
            // Demote to background: detach UI handle but keep the WKWebView alive.
            store.detachWebViewForBackground()
            CoreKitMetrics.recordTabDeactivatedWarm()
        case .cold:
            store.deactivateCold()
            CoreKitMetrics.recordTabDeactivatedCold()
        }
        activeWebViewsLRU.removeAll { $0 == tabID }
        activePaneByTabID.removeValue(forKey: tabID)
    }

    @MainActor
    private func enforceMaxConcurrentViewsBeforeActivating(
        activatingTabID: UUID,
        paneID: String,
        protectedTabIDs: Set<UUID>
    ) async {
        let maxConcurrent = maxConcurrentViewsLimit
        if activeWebViewsLRU.count < maxConcurrent { return }

        // Prefer evicting non-protected views first.
        var protected = protectedTabIDs
        protected.insert(activatingTabID)

        while activeWebViewsLRU.count >= maxConcurrent {
            // Try: global LRU candidate that is not protected.
            if let candidate = activeWebViewsLRU.reversed().first(where: { !protected.contains($0) }) {
                deactivateWebViewIfActive(tabID: candidate, mode: .warm)
                continue
            }

            // Fallback: if everything is protected, we must still replace one existing view.
            // Replace the global LRU (but never the one we're trying to activate).
            if let fallback = activeWebViewsLRU.last, fallback != activatingTabID {
                deactivateWebViewIfActive(tabID: fallback, mode: .warm)
                continue
            }

            break
        }

        #if DEBUG
        if activeWebViewsLRU.count > maxConcurrent {
            assertionFailure(
                "[TabRegistry] enforceMaxConcurrentViewsBeforeActivating failed. activeLRU=\(activeWebViewsLRU.count) max=\(maxConcurrent) windowID=\(windowID)"
            )
        }
        #endif
    }

    #if DEBUG
    public func debugDescribeState() -> String {
        let pools: String = webViewPoolByPaneID
            .map { pane, pool in
                "pane=\(pane) \(pool.debugDescribeState())"
            }
            .sorted()
            .joined(separator: " | ")
        return "TabRegistry(windowID=\(windowID) profile=\(browsingProfile) aliveStores=\(aliveStoresCount) activeCount=\(activeWebViewsCount) maxAlive=\(debugMaxAliveWebViewsLimit) maxConcurrent=\(debugMaxConcurrentViewsLimit) activeLRU=\(activeWebViewsLRU.map { $0.uuidString.prefix(8) }.joined(separator: ","))) pools={\(pools)}"
    }
    #endif

    @MainActor
    private func trimIfNeeded() async {
        while lru.count > maxAliveWebViewsLimit, let last = lru.last {
            await remove(tabID: last)
        }
    }
}

// MARK: - WebViewPool Budget Delegate

@MainActor
extension TabRegistry: WebViewPool.BudgetDelegate {
    public func webViewPool(_ pool: WebViewPool, evictTabID: UUID, reason: WebViewPool.EvictionReason) {
        // Pool-level eviction should keep the store alive but remove the WKWebView.
        // Discard must not leave UX restore in a timedOut state.
        discardWebView(tabID: evictTabID)
    }
}

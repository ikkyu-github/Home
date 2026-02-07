import Foundation
import SafariLikeCoreKit

@MainActor
extension SplitBrowserViewModel {
    // MARK: Scene / WebView lifecycle
    func setSceneIsActive(_ isActive: Bool) {
        mutateAsync {
            self.isSceneActive = isActive
        }
        // Best-effort: when we become active, re-apply preferences for the current host.
        // This is safe even if there is no active WKWebView yet.
        if isActive {
            Task { @MainActor [weak self] in
                guard let self else { return }
                await Task.yield()
                self.applyWebsitePreferencesForActiveHost()
            }
        }
    }

    // MARK: - Rendering (UI)
    /// UI-facing read-only access to the currently active web view handle.
    ///
    /// BrowserPaneView must not reach into `activeStore.webViewHandle` directly.
    internal var activeWebViewHandleForRendering: WebViewHandle? {
        activeStore?.webViewHandle
    }

    /// UI-facing read-only access to the currently active WebContext.
    ///
    /// This is intentionally narrow: views should not poke into the WebContext beyond
    /// what is required to render, while render budgeting remains owned by the runtime.
    internal var activeWebContextForRendering: WebContext? {
        activeStore?.webContext
    }

    /// UI-facing read-only access to a tab's current WebView handle (if attached).
    ///
    /// Views must not reach into `TabWebStore.webContext`.
    internal func webViewHandleForRendering(tabID: UUID) -> WebViewHandle? {
        tabManager.runtimeStoreIfAlive(for: tabID)?.webViewHandle
    }

    /// UI bridge: protocol-only handle for reporting reality snapshots.
    internal func runtimeRealityUpdaterIfAlive(for tabID: UUID) -> (any WebViewRealityUpdating)? {
        tabManager.runtimeStoreIfAlive(for: tabID)
    }

    /// UI read: UX restore state without exposing a concrete store.
    internal func uxRestoreStateIfAlive(tabID: UUID) -> UXRestoreController.State? {
        tabManager.runtimeStoreIfAlive(for: tabID)?.uxRestoreController.state
    }

    /// Lifecycle read: latest reality snapshot without exposing a concrete store.
    internal func webViewRealityIfAlive(tabID: UUID) -> WebViewRealitySnapshot? {
        tabManager.runtimeStoreIfAlive(for: tabID)?.currentWebViewReality
    }

    /// Lifecycle: protocol-only observation surface (reality + restore).
    internal func runtimeRealityObserverIfAlive(for tabID: UUID) -> (any WebViewRealityObserving)? {
        tabManager.runtimeStoreIfAlive(for: tabID)
    }

    internal func requiresWebView(tabID: UUID?) -> Bool {
        guard let tabID else { return false }
        let tabState = sessionStore.tabs.first(where: { $0.id == tabID })?.state
        return WebViewRequirementPolicy.decide(tabState: tabState).requiresWebView
    }

    private func webContentVisibilitySnapshot(tabID: UUID) -> WebContentVisibilityPolicy.Snapshot {
        // Prefer runtime truth: if a live handle exists, show web content.
        let handle = webViewHandleForRendering(tabID: tabID)
            ?? (tabID == activeTabID ? activeWebViewHandleForRendering : nil)
        let hasLiveHandle = (handle?.isAlive == true)
        return .init(hasLiveWebViewHandle: hasLiveHandle)
    }

    /// Single source of truth: whether the UI should show *web content* for a given tab.
    ///
    /// Rationale: `BrowserTab.State` can transiently drift (e.g. Start Page) even after the
    /// runtime has produced/attached a WKWebView. When a live handle exists, the web surface
    /// must win so placeholder/start-page layers cannot cover the WKWebView.
    internal func shouldShowWebContent(tabID: UUID?) -> Bool {
        guard let tabID else { return false }
        return WebContentVisibilityPolicy.decide(webContentVisibilitySnapshot(tabID: tabID)).shouldPreferWebContent
    }

    /// Convenience for the currently active tab.
    internal var shouldShowWebContentForActiveTab: Bool {
        activeWebContentVisibilityDecision.shouldPreferWebContent
    }

    internal func refreshActiveWebContentVisibilityDecision() {
        guard let tabID = activeTabID else {
            activeWebContentVisibilityDecision = .showNonWebContent
            return
        }
        activeWebContentVisibilityDecision = WebContentVisibilityPolicy.decide(webContentVisibilitySnapshot(tabID: tabID))
    }

    /// UI reconciler: when runtime reality says web is present, ensure we re-render away any
    /// StartPage/Empty overlays that could be covering the WKWebView.
    internal func reconcileWebContentVisibility(reason: String) {
        guard let tabID = activeTabID else { return }
        let snapshot = webContentVisibilitySnapshot(tabID: tabID)
        let decision = WebContentVisibilityPolicy.decide(snapshot)
        activeWebContentVisibilityDecision = decision

        if decision.shouldPreferWebContent {
            // If the session still thinks we're on Start Page, force a full subtree refresh once.
            // (The view tree might otherwise keep showing Start Page over the web lane.)
            if isStartPageActiveTab, didReconcileWebVisibilityForTabIDs.contains(tabID) == false {
                didReconcileWebVisibilityForTabIDs.insert(tabID)
                Diagnostics.logInfo(
                    "[UIVisibility] Live web handle exists while StartPage is active; forcing UI rerender. reason=\(reason)",
                    subsystem: .ui,
                    category: "WebView"
                )
                requestUIRerender()
            }
        } else {
            // Reset the one-shot guard once web content is gone.
            didReconcileWebVisibilityForTabIDs.remove(tabID)
        }
    }

    // MARK: - WebView attachment (single source of truth)
    /// Best-effort runtime assertion (no crash): if UI believes we're ready but handle is missing,
    /// downgrade to `.attaching` via LifecycleCoordinator and emit an error log.
    internal func assertReadyStateHasWebViewHandle(tabID: UUID) {
        guard let runtimeContext else { return }
        guard runtimeContext.currentAttachmentStatus()?.tabID == tabID else { return }
        guard let state = runtimeContext.currentAttachmentStatus()?.state else { return }
        guard case .ready = state else { return }
        guard activeStore?.webViewHandle != nil else {
            Diagnostics.logError(
                "Attachment invariant violated: state=ready but activeStore.webViewHandle is nil (tabID=\(tabID.uuidString))",
                subsystem: .runtime,
                category: "WebViewAttachment"
            )
            runtimeContext.handleBrowserRuntimeEvent(.webViewDetached(tabID: tabID), viewModel: self, tabManager: tabManager)
            return
        }
    }

    // MARK: Lifecycle intents (emit only)
    /// Lifecycle intent: root view is on-screen and it's safe to start/attach runtime.
    func notifyRootViewAppeared() {
        guard let runtimeContext else { return }
        runtimeContext.handleBrowserRuntimeEvent(.rootViewAppeared, viewModel: self, tabManager: tabManager)
    }

    /// Lifecycle intent: WebView host has attached.
    func notifyWebViewAttached(tabID: UUID) {
        guard let runtimeContext else { return }
        runtimeContext.handleBrowserRuntimeEvent(.webViewAttached(tabID: tabID), viewModel: self, tabManager: tabManager)
    }

    /// Lifecycle intent: WebView host has detached.
    func notifyWebViewDetached(tabID: UUID) {
        guard let runtimeContext else { return }
        runtimeContext.handleBrowserRuntimeEvent(.webViewDetached(tabID: tabID), viewModel: self, tabManager: tabManager)
    }

    /// Lifecycle intent: request reconcile for a tab.
    func requestReconcile(tabID: UUID, reason: String) {
        guard let runtimeContext else { return }
        runtimeContext.requestReconcile(tabID: tabID, viewModel: self, tabManager: tabManager, reason: reason)
    }

    /// Recovery intent used by BrowserPaneView: deterministic retry without Views calling into runtime context.
    func retryInPlace(tabID: UUID?) {
        let fallback = tabID.flatMap { id in
            sessionStore.tabs.first(where: { $0.id == id })?.urlString
        }
        Task { @MainActor in
            // Deterministic retry: clear any in-flight binding so the next attach is a clean slate.
            tabManager.unbindActiveStore(cancelBindTask: true)
            if let tabID {
                notifyWebViewDetached(tabID: tabID)
            }
            await windowCoordinator.retryInPlace(tabID: tabID, fallbackURLString: fallback)
            if let tabID {
                // Seed attachment again after retry in case detached event wasn't sufficient.
                if let runtimeContext {
                    runtimeContext.handleBrowserRuntimeEvent(.tabActivated(tabID: tabID), viewModel: self, tabManager: tabManager)
                }
                // Reality-wins: if the WebView is already alive/attached, never let `.timedOut` stick.
                requestReconcile(tabID: tabID, reason: "retry")
            }
        }
    }

    /// Recovery intent used by BrowserPaneView: rebind active tab runtime when invariants are violated.
    func triggerWebViewRecovery(tabID: UUID, reason: String) async {
        tabManager.unbindActiveStore(cancelBindTask: true)
        notifyWebViewDetached(tabID: tabID)
        if let runtimeContext {
            runtimeContext.handleBrowserRuntimeEvent(.tabActivated(tabID: tabID), viewModel: self, tabManager: tabManager)
        }
        send(.forceAttachWebView)
        requestReconcile(tabID: tabID, reason: reason)
    }

    // MARK: Mode API
    func togglePrivateMode() {
        let next: BrowsingProfile = isPrivateMode ? .regular : .private
        windowCoordinator.setBrowsingProfile(next)
    }

    // MARK: Website settings & share
    func applyWebsitePreferencesForActiveHost() {
        // Best-effort and idempotent: glue layer already guards missing store/webView.
        glue.applyWebsitePreferencesForActiveHost()
    }

    func zoomIn() { glue.zoomIn() }
    func zoomOut() { glue.zoomOut() }
    func resetZoom() { glue.resetZoom() }
    func toggleDesktopMode() { glue.toggleDesktopMode() }
    func toggleReaderDefault() { glue.toggleReaderDefault() }
    func applyReaderPreferencesForActiveHost() { glue.applyReaderPreferencesForActiveHost() }
    func resetWebsiteSettings() { glue.resetWebsiteSettings() }

    // MARK: - Reader Mode
    func toggleReaderMode() { glue.toggleReaderModeForActiveTab() }

    func handleReaderPageDidFinish(tabID: UUID, store: SafariLikeCoreKit.TabWebStore, url: URL?) {
        glue.refreshReaderStateAfterPageDidFinish(tabID: tabID, store: store, url: url)
    }

    private func shareCurrentPage() { glue.shareCurrentPage() }
}

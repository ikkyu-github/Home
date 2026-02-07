
import Foundation
import BrowserCore
import SafariLikeCoreKit

@MainActor
final class TabLifecycleController {
    weak var manager: TabManager?
    private var tabSelectionCancellable: Any?

    init(manager: TabManager) {
        self.manager = manager
    }

    @MainActor
    func rebuildTabsFromSessionAndEnsureSelection(preferredActiveID: UUID? = nil) {
        guard let manager else {
            assertionFailure("TabLifecycleController.manager deallocated before rebuild")
            return
        }
        // Sync manager.tabs with sessionStore.tabs
        let sessionTabs = manager.sessionStore.tabs
        // TabManager owns its own tab snapshot via Combine subscriptions.

        // Determine active tab
        let activeID: UUID? = preferredActiveID ?? sessionTabs.first?.id
        if let activeID = activeID {
            manager.selectTab(activeID)
        }
    }

    @MainActor
    func bindSessionSelection(for store: BrowserSessionStore) {
        guard manager != nil else {
            assertionFailure("TabLifecycleController.manager deallocated before bindSessionSelection")
            return
        }
        // Subscribe to active tab changes in session store
        // (Assume sessionStore exposes a publisher for activeTabID, or use KVO/Combine if available)
        // For demo, poll activeTabID (replace with publisher in real code)
        // If Combine publisher exists: tabSelectionCancellable = store.activeTabIDPublisher.sink { [weak self] id in self?.manager.selectTab(id) }
    }

    @MainActor
    func enableSplitView() {
        guard let manager else {
            assertionFailure("TabLifecycleController.manager deallocated before enableSplitView")
            return
        }

        // 1) Enable split (preserve existing behavior)
        manager.isSplitViewEnabled = true
        manager.activePane = .left

        // 2) Ensure leftTabID
        if manager.leftTabID == nil {
            manager.leftTabID =
                manager.currentSessionStore.selectedTabID
                ?? manager.activeTabID
                ?? manager.currentSessionStore.tabs.first?.id
        }
        if manager.leftTabID == nil {
            // No tabs in the session store yet; create a primary tab to anchor split.
            manager.leftTabID = manager.newTab(inBackground: false)
        }

        // 3) Ensure rightTabID
        if manager.rightTabID == nil {
            if let left = manager.leftTabID,
               let existing = manager.currentSessionStore.tabs.first(where: { $0.id != left })?.id {
                manager.rightTabID = existing
            } else {
                let oldPane = manager.activePane
                manager.activePane = .right
                let newID = manager.newTab(inBackground: true)
                manager.activePane = oldPane
                manager.rightTabID = newID
            }
        }
        if let left = manager.leftTabID, manager.rightTabID == left {
            let oldPane = manager.activePane
            manager.activePane = .right
            let newID = manager.newTab(inBackground: true)
            manager.activePane = oldPane
            manager.rightTabID = newID
        }

        // 4) Assign pane ownership explicitly
        if let left = manager.leftTabID {
            manager.assignTab(left, to: .primary)
        }
        if let right = manager.rightTabID {
            manager.assignTab(right, to: .secondary)
        }

        // 5) Activate right pane as companion (ensure webViewHandle exists)
        if let right = manager.rightTabID {
            Task { @MainActor [weak manager] in
                guard let manager else { return }
                guard manager.sessionStore.tabs.contains(where: { $0.id == right }) else { return }
                guard manager.state.isTabOverviewVisible == false else { return }

                var protected: Set<UUID> = []
                if manager.isSplitViewEnabled {
                    if let left = manager.leftTabID { protected.insert(left) }
                    if let right = manager.rightTabID { protected.insert(right) }
                }

                guard let runtime = manager.runtime(for: right, role: .companion) else {
                    RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
                    return
                }
                let store = await runtime.activate(protectedTabIDs: protected)
                manager.setLifecycle(tabID: right, lifecycle: .active, runtimeAttachment: .attached)

                if store.state.currentURL != nil { return }
                let preferredURL = manager.sessionStore.tabs.first(where: { $0.id == right })?.urlString
                let trimmed = preferredURL?.trimmingCharacters(in: .whitespacesAndNewlines)
                let url = (trimmed?.isEmpty == false ? trimmed : nil) ?? manager.defaultHomeURLString
                let navigation = manager.navigationService ?? NavigationService(tabManager: manager)
                navigation.loadURLString(url, in: store, force: true)
            }
        }

        applyRenderBudget(reason: "split.enabled")
    }

    @MainActor
    func disableSplitView() {
        guard let manager else {
            assertionFailure("TabLifecycleController.manager deallocated before disableSplitView")
            return
        }
        manager.isSplitViewEnabled = false
        manager.activePane = .left
        manager.rightTabID = nil

        if manager.leftTabID == nil {
            manager.leftTabID =
                manager.currentSessionStore.selectedTabID
                ?? manager.activeTabID
                ?? manager.currentSessionStore.tabs.first?.id
        }

        applyRenderBudget(reason: "split.disabled")
    }

    // MARK: - Render Budget

    /// Enforce a Safari-like render budget:
    /// - split disabled => max 1 live web view
    /// - split enabled  => max 2 live web views (left + right)
    ///
    /// Threading: main actor.
    @MainActor
    func applyRenderBudget(reason: String) {
        guard let manager else {
            assertionFailure("TabLifecycleController.manager deallocated before applyRenderBudget")
            return
        }

        // During session restore we avoid eager WebView creation/teardown.
        guard manager.isPerformingSessionRestore == false else { return }

        let candidates = manager.currentTabRegistry.aliveTabIDs

        let bindingTabID: UUID? = {
            switch manager.activeBindingState {
            case .binding(let id), .bound(let id), .unbinding(let id):
                return id
            case .unbound:
                return nil
            }
        }()

        let policyInput = RenderBudgetPolicy.Input(
            isSplitEnabled: manager.isSplitViewEnabled,
            isTabOverviewVisible: manager.state.isTabOverviewVisible,
            activePane: (manager.activePane == .right) ? .right : .left,
            activeTabID: manager.activeTabID,
            leftTabID: manager.leftTabID,
            rightTabID: manager.rightTabID,
            bindingTabID: bindingTabID
        )

        let decision = RenderBudgetPolicy.decide(input: policyInput, candidates: candidates)

        // Hard clamp:
        // - Overview => render budget 0 (snapshot-only)
        // - Normal   => only active primary + active secondary (if split)
        let allowedToRender: Set<UUID> = {
            if manager.state.isTabOverviewVisible { return [] }
            var allowed: Set<UUID> = []
            if manager.isSplitViewEnabled {
                if let left = manager.leftTabID { allowed.insert(left) }
                if let right = manager.rightTabID { allowed.insert(right) }
            } else {
                if let active = manager.activeTabID {
                    allowed.insert(active)
                } else if let selected = manager.currentSessionStore.selectedTabID {
                    allowed.insert(selected)
                }
            }
            if let bindingTabID { allowed.insert(bindingTabID) }
            return allowed
        }()

        let keepSet = Set(decision.keepRendered).intersection(allowedToRender)

        // Update debug overlay (best-effort, DEBUG-only UI but model exists in all builds).
        if DiagnosticsGate.isEnabled {
            let summary: String = {
                // Keep this short; overlay has limited width.
                let live = manager.currentTabRegistry.aliveTabIDs
                    .compactMap { id -> String? in
                        guard let s = manager.state.tabs.first(where: { $0.id == id }) else { return nil }
                        if s.runtimeAttachment == .attached { return "L" }
                        if s.snapshotData != nil { return "S" }
                        return "U"
                    }
                // Example: tabs=30 live=2 [L,S,U,...]
                return "tabs=\(manager.state.tabs.count) live=\(WebViewPool.shared.liveWebViewCount)" + (live.isEmpty ? "" : " states=\(live.prefix(12).joined())")
            }()
            PerformanceOverlayModel.shared.setRenderStateSummary(summary)
        }

        // 1) Freeze non-kept live views.
        for tabID in candidates where !keepSet.contains(tabID) {
            guard let store = manager.currentTabRegistry.existingStore(for: tabID) else { continue }
            guard store.webViewHandle != nil else { continue }

            // Best-effort: capture a snapshot right before demotion so tab cards can render
            // snapshot/title/favicon without needing a live WKWebView.
            if let webView = store.webView {
                manager.snapshotService.captureSnapshot(
                    tabID: tabID,
                    webView: webView,
                    targetWidth: 520,
                    minInterval: 0.75,
                    jpegQuality: 0.65
                )
                RuntimeMetrics.shared.increment(.snapshotCaptured)
                Diagnostics.logInfo(
                    "[RenderBudget] snapshot tabID=\(tabID) reason=\(reason)",
                    subsystem: .runtime,
                    category: "RenderBudget"
                )
            }

            store.freezeWebView()
            RuntimeMetrics.shared.increment(.renderBudgetFreeze)
            RuntimeMetrics.shared.increment(.webViewDeactivated)
            Diagnostics.logInfo(
                "[RenderBudget] freeze tabID=\(tabID) reason=\(reason)",
                subsystem: .runtime,
                category: "RenderBudget"
            )
        }

        // 2) Ensure kept views are attached (best-effort, only for existing stores).
        // Never activate new webviews while overview is visible.
        guard manager.state.isTabOverviewVisible == false else { return }
        for tabID in decision.keepRendered {
            guard keepSet.contains(tabID) else { continue }
            guard let store = manager.currentTabRegistry.existingStore(for: tabID) else { continue }
            guard store.webViewHandle == nil else { continue }

            // Go through the runtime/registry so activation participates in the global
            // webview budget and active tracking.
            guard let runtime = manager.runtime(for: tabID) else {
                RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
                continue
            }
            Task { @MainActor [weak manager] in
                guard manager != nil else { return }
                _ = await runtime.activate(protectedTabIDs: keepSet)
                RuntimeMetrics.shared.increment(.webViewActivated)
            }
        }
    }

    @MainActor
    func unbindActiveStore(cancelBindTask: Bool = false) {
        guard let manager else {
            assertionFailure("TabLifecycleController.manager deallocated before unbindActiveStore")
            return
        }
        manager.unbindActiveStore(cancelBindTask: cancelBindTask)
        manager.activeBindingState = .unbound
    }
}

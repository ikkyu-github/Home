import Foundation
import SafariLikeCoreKit
@MainActor
final class TabBudgetController {
    private unowned let manager: TabManager
    private var lastRenderVisibilitySummary: String?
    private var lastPerformanceTierByTabID: [UUID: WebViewPerformanceTier] = [:]
    init(manager: TabManager) {
        self.manager = manager
    }

    func reconcileRenderVisibilityPolicy(reason: String) {
        guard manager.isPerformingSessionRestore == false else { return }

        let manager = self.manager

        let isWebTab: (UUID) -> Bool = { id in
            guard let tab = manager.currentSessionStore.tabs.first(where: { $0.id == id }) else { return false }
            if case .web = tab.state { return true }
            return false
        }

        let visibleSet: Set<UUID> = Set(manager.currentVisiblePaneTabIDs())
        let activeTabCandidate: UUID? = manager.activeTabID ?? manager.currentSessionStore.selectedTabID

        let aliveWebCandidates = manager.currentTabRegistry.aliveTabIDs.filter(isWebTab)
        guard let core = manager.runtimeContextIfAvailable?.core else {
            return
        }

        let snapshot = SafariLikeCoreKit.TabPageLifecycleStateMachine.VisibilitySnapshot(
            isSplitEnabled: manager.isSplitPanePresentationActive,
            isTabOverviewVisible: manager.state.isTabOverviewVisible,
            activePane: (manager.activePane == .right) ? .right : .left,
            activeTabID: activeTabCandidate,
            leftTabID: manager.leftTabID,
            rightTabID: manager.rightTabID,
            bindingTabID: (manager.bindingTabID.flatMap { isWebTab($0) ? $0 : nil })
        )

        let effects = core.handleTabPageLifecycleEvent(.reconcileVisibility(snapshot: snapshot, candidates: aliveWebCandidates, reason: reason))

        // Derive keepSet from CoreKit state after reconciliation.
        let keepSet: Set<UUID> = Set(aliveWebCandidates.filter { core.tabPageLifecycleState(tabID: $0) == .liveAttached })
        let keepSummary = keepSet.prefix(4).map { $0.uuidString }.joined(separator: ",")
        let summary = "keep=\(keepSet.count)[\(keepSummary)]"
        if summary != lastRenderVisibilitySummary {
            manager.recordRenderPolicyInfo(
                "[RenderPolicy] change reason=\(reason) prev=\(lastRenderVisibilitySummary ?? "nil") next=\(summary) overview=\(manager.state.isTabOverviewVisible) split=\(manager.isSplitPanePresentationActive) visible=\(visibleSet.count)"
            )
            lastRenderVisibilitySummary = summary
        }

        manager.tabTasks.cancelTasks(
            exceptKeepSet: keepSet,
            keys: Set([.ensureLoaded, .renderBudgetActivate, .splitCompanionActivate, .scrollRestore])
        )

        CoreKitLifecycleEffectApplier.apply(effects, manager: manager)

        // UI-facing render mode mapping (deterministic; does not decide WebView attachment).
        let activePaneTabID: UUID? = {
            guard manager.isSplitPanePresentationActive else { return activeTabCandidate }
            switch (manager.activePane == .right) ? BrowserCore.RenderBudgetPolicy.ActivePane.right : .left {
            case .right:
                return manager.rightTabID ?? activeTabCandidate
            case .left:
                return manager.leftTabID ?? activeTabCandidate
            @unknown default:
                return activeTabCandidate
            }
        }()

        let previewTabID: UUID? = {
            guard manager.isSplitPanePresentationActive else {
                guard let binding = manager.bindingTabID, binding != activePaneTabID else { return nil }
                return binding
            }
            let other: UUID? = (manager.activePane == .right) ? manager.leftTabID : manager.rightTabID
            guard other != activePaneTabID else { return nil }
            return other
        }()

        manager.mutateState { state in
            for idx in state.tabs.indices {
                let id = state.tabs[idx].id
                if state.tabs[idx].lifecycle == .discarded || state.tabs[idx].lifecycle == .closed {
                    state.tabs[idx].renderMode = .discarded
                    continue
                }
                if id == activePaneTabID, keepSet.contains(id) {
                    state.tabs[idx].renderMode = .active
                } else if id == previewTabID, keepSet.contains(id) {
                    state.tabs[idx].renderMode = .preview
                } else {
                    state.tabs[idx].renderMode = .frozen
                }
            }
        }

        // Performance tiers remain visibility-driven.
        for tab in manager.currentSessionStore.tabs {
            let tabID = tab.id
            let tier: WebViewPerformanceTier
            if activeTabCandidate == tabID {
                tier = .foreground
            } else if visibleSet.contains(tabID) {
                tier = .backgroundVisible
            } else {
                tier = .backgroundHidden
            }
            if lastPerformanceTierByTabID[tabID] == tier { continue }
            lastPerformanceTierByTabID[tabID] = tier
            guard let store = manager.runtimeStoreIfAlive(for: tabID) else { continue }
            store.setPerformanceTier(tier)
            if tier == .backgroundHidden, store.webViewHandle != nil {
                manager.requestDeactivateWebView(tabID: tabID, mode: .warm, reason: "perfTier.backgroundHidden")
            }
        }
    }

    func setTabOverviewVisible(_ visible: Bool) {
        guard manager.state.isTabOverviewVisible != visible else { return }
        manager.mutateState { $0.isTabOverviewVisible = visible }
        manager.normalTabRegistry.setActivationSuppressed(visible)
        manager.privateTabRegistry.setActivationSuppressed(visible)

        if manager.isPerformingSessionRestore == false {
            manager.lifecycleController.applyRenderBudget(reason: visible ? "overview.enter" : "overview.exit")
        }
    }

    func prewarmHeuristicsCandidatesIfNeeded() {
        guard manager.state.isTabOverviewVisible == false else { return }
        guard manager.pendingHeuristicsPrewarmTabIDs.isEmpty == false else { return }

        let allowedLive = manager.visiblePaneCount
        let currentLive = manager.normalTabRegistry.activeWebViewsCount + manager.privateTabRegistry.activeWebViewsCount
        let availableBudget = max(0, allowedLive - currentLive)
        guard availableBudget > 0 else { return }

        var protected: Set<UUID> = []
        if let selected = manager.currentSessionStore.selectedTabID { protected.insert(selected) }
        protected.formUnion(manager.currentVisiblePaneTabIDs())

        let candidates = manager.pendingHeuristicsPrewarmTabIDs.filter { protected.contains($0) == false }
        manager.pendingHeuristicsPrewarmTabIDs.removeAll()

        let maxPrewarm = min(2, availableBudget)
        let toPrewarm = Array(candidates.prefix(maxPrewarm))
        guard toPrewarm.isEmpty == false else { return }

        Task { @MainActor [weak manager] in
            guard let manager else { return }
            guard manager.state.isTabOverviewVisible == false else { return }
            for tabID in toPrewarm {
                guard manager.sessionStore.tabs.contains(where: { $0.id == tabID }) else { continue }
                let webTx = manager.beginWebViewTransition(reason: "heuristicsPrewarm", tabID: tabID)
                _ = await manager.activateRuntimeStore(
                    tabID: tabID,
                    role: .primary,
                    protectedTabIDs: protected,
                    token: webTx,
                    reason: "heuristicsPrewarm"
                )
            }
        }
    }
}

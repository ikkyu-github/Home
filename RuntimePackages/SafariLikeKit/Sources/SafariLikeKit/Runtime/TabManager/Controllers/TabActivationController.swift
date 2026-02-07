import Foundation
import SafariLikeCoreKit

@MainActor
final class TabActivationController {
    private unowned let manager: TabManager
    // MARK: - Active Tab Binding Transactions
    private var bindingTransactionCounter: UInt64 = 0
    private var currentBindingTransactionID: UInt64 = 0
    init(manager: TabManager) {
        self.manager = manager
    }

    func beginBindingTransaction(reason: String, targetTabID: UUID) -> UInt64 {
        bindingTransactionCounter &+= 1
        currentBindingTransactionID = bindingTransactionCounter
        if DiagnosticsGate.isEnabled {
            Diagnostics.logInfo(
                "[BindTx] begin tx=\(currentBindingTransactionID) reason=\(reason) target=\(targetTabID.uuidString)",
                subsystem: .runtime,
                category: "TabBinding"
            )
        }
        return currentBindingTransactionID
    }

    func isCurrentBindingTransaction(_ tx: UInt64) -> Bool {
        tx == currentBindingTransactionID
    }
    func logBindingRace(kind: String, tx: UInt64, tabID: UUID, context: String) {
        guard DiagnosticsGate.isEnabled else { return }
        let selected = manager.sessionStore.selectedTabID?.uuidString ?? "nil"
        let active = manager.activeTabID?.uuidString ?? "nil"
        Diagnostics.logError(
            "[BindTx] race kind=\(kind) tx=\(tx) currentTx=\(currentBindingTransactionID) tab=\(tabID.uuidString) selected=\(selected) active=\(active) state=\(String(describing: manager.activeBindingState)) ctx=\(context)",
            subsystem: .runtime,
            category: "TabBinding"
        )
    }

    // MARK: - Pane-aware ownership
    func paneID(for tabID: UUID) -> String {
        if let pane = manager.state.tabs.first(where: { $0.id == tabID })?.paneID {
            return pane.rawValue
        }
        if let assigned = manager.tabPaneAssignments[tabID] { return assigned.rawValue }
        if manager.isSplitViewEnabled, manager.rightTabID == tabID {
            return PaneID.secondary.rawValue
        }
        return PaneID.primary.rawValue
    }
    func assignTab(_ tabID: UUID, to pane: PaneID) {
        let previousPane = manager.state.tabs.first(where: { $0.id == tabID })?.paneID
        manager.tabPaneAssignments[tabID] = pane
        manager.mutateState { state in
            guard let idx = state.tabs.firstIndex(where: { $0.id == tabID }) else { return }
            state.tabs[idx].paneID = pane
        }
        if let previousPane, previousPane != pane {
            manager.requestDeactivateWebView(tabID: tabID, mode: .warm, reason: "pane.move")
        }
    }

    func removePaneAssignment(for tabID: UUID) {
        manager.tabPaneAssignments.removeValue(forKey: tabID)
    }
    // MARK: - Selection
    func selectTab(_ id: UUID) {
        let previousSelected = manager.currentSessionStore.selectedTabID
        if manager.isSplitViewEnabled == false {
            assignTab(id, to: .primary)
        }
        manager.activeTabID = id
        manager.currentSessionStore.selectTab(id: id)
        manager.onActiveTabChanged?(id)
        if let host = manager.pluginHost {
            _ = host.getOrCreatePluginManager(for: id.uuidString)
        }
        if let previousSelected, previousSelected != id {
            manager.pluginSessionProvider.publish(.tabDidChange(from: previousSelected.uuidString, to: id.uuidString))
        }
        RuntimeMetrics.shared.increment(.tabSelected)
        manager.recordLifecycleEvent("tab.selected")
        guard manager.isPerformingSessionRestore == false else { return }
        manager.tabCoordinator.activateTab(id)
        manager.lifecycleController.applyRenderBudget(reason: "tab.selected")
    }

    // MARK: - Tabs (Create/Delete)
    func newTab(inBackground: Bool = false) -> UUID {
        let newTabID = manager.currentSessionStore.addTab()
        let targetPane: PaneID = {
            guard manager.isSplitViewEnabled else { return .primary }
            return (manager.activePane == .right) ? .secondary : .primary
        }()
        assignTab(newTabID, to: targetPane)
        RuntimeMetrics.shared.increment(.tabCreated)
        manager.recordLifecycleEvent("tab.created")
        if !inBackground {
            manager.activeTabID = newTabID
            manager.currentSessionStore.selectTab(id: newTabID)
            manager.onActiveTabChanged?(newTabID)
            manager.tabCoordinator.activateTab(newTabID)
        }
        return newTabID
    }
    func closeTabAsync(_ id: UUID) async {
        RuntimeMetrics.shared.increment(.tabClosed)
        manager.recordLifecycleEvent("tab.closed")
        manager.tabTasks.cancelAll(for: id, excluding: [.close])

        manager.invalidateSnapshot(tabID: id, reason: "tab.closed")

        let paneAtClose = paneID(for: id)
        let wasSelectedTab = (manager.currentSessionStore.selectedTabID == id)
        let wasBoundToClosedTab: Bool = {
            if case let .bound(boundID) = manager.activeBindingState, boundID == id { return true }
            return false
        }()
        manager.withCurrentSessionStore { store in
            store.closeTab(id: id)
        }
        let nextSelected = manager.currentSessionStore.selectedTabID
        if (wasSelectedTab || wasBoundToClosedTab), let nextSelected, nextSelected != id {
            manager.activeBindingState = .binding(nextSelected)
        }
        if wasBoundToClosedTab {
            manager.tabCoordinator.unbindActiveStore(preserveManagerBindingState: nextSelected != nil)
        }
        await manager.currentTabRegistry.remove(tabID: id)
        manager.destroyRuntime(for: id)
        manager.removeRenderController(tabID: id)
        removePaneAssignment(for: id)
        _ = paneAtClose

        if manager.isPerformingSessionRestore == false, (wasSelectedTab || wasBoundToClosedTab), let nextSelected {
            manager.activeTabID = nextSelected
            manager.tabCoordinator.activateTab(nextSelected)
            manager.lifecycleController.applyRenderBudget(reason: "tab.closed")
        } else if nextSelected == nil {
            manager.activeBindingState = .unbound
        }
    }
    func closeTab(_ id: UUID) {
        manager.tabTasks.replaceTask(tabID: id, key: .close) {
            Task { @MainActor [weak manager] in
                guard let manager else { return }
                await manager.closeTabAsync(id)
            }
        }
    }

    func activateTab(_ id: UUID) {
        manager.activeTabID = id
        manager.tabCoordinator.activateTab(id)
        manager.lifecycleController.applyRenderBudget(reason: "tab.activated")
    }

    func selectLeftPane() {
        manager.tabCoordinator.selectLeftPane()
        manager.lifecycleController.applyRenderBudget(reason: "pane.left")
    }

    func selectRightPane() {
        manager.tabCoordinator.selectRightPane()
        manager.lifecycleController.applyRenderBudget(reason: "pane.right")
    }
    // MARK: - Policy-driven new tabs
    func openInNewTabFromPolicy(request: URLRequest) {
        guard manager.state.isTabOverviewVisible == false else { return }
        guard let url = request.url else { return }
        let urlString = url.absoluteString
        let newTabID = newTab(inBackground: false)
        Task { @MainActor [weak manager] in
            guard let manager else { return }
            guard manager.state.isTabOverviewVisible == false else { return }
            var protected: Set<UUID> = []
            if manager.isSplitViewEnabled {
                if let left = manager.leftTabID { protected.insert(left) }
                if let right = manager.rightTabID { protected.insert(right) }
            }
            let webTx = manager.beginWebViewTransition(reason: "openInNewTabFromPolicy", tabID: newTabID)
            guard let store = await manager.activateRuntimeStore(
                tabID: newTabID,
                role: .primary,
                protectedTabIDs: protected,
                token: webTx,
                reason: "openInNewTabFromPolicy"
            ) else { return }
            guard manager.isCurrentWebViewTransition(tabID: newTabID, token: webTx) else { return }
            let navigation = manager.navigationService ?? NavigationService(tabManager: manager)
            navigation.loadURLString(urlString, in: store, force: true)
        }
    }
}

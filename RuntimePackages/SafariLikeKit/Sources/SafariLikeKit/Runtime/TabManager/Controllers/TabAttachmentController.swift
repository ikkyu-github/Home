import Foundation
import SafariLikeCoreKit

@MainActor
final class TabAttachmentController {
    private unowned let manager: TabManager

    // MARK: - WebView Transition Tokens (Single Writer)
    private var webViewTransitionCounter: UInt64 = 0
    private var currentWebViewTransitionByTabID: [UUID: UInt64] = [:]

    init(manager: TabManager) {
        self.manager = manager
    }

    func beginWebViewTransition(reason: String, tabID: UUID) -> UInt64 {
        webViewTransitionCounter &+= 1
        let token = webViewTransitionCounter
        currentWebViewTransitionByTabID[tabID] = token
        if DiagnosticsGate.isEnabled {
            Diagnostics.logDebug(
                "[WebViewTx] begin tx=\(token) reason=\(reason) tab=\(tabID.uuidString)",
                subsystem: .runtime,
                category: "WebViewTransition"
            )
        }
        return token
    }

    func isCurrentWebViewTransition(tabID: UUID, token: UInt64) -> Bool {
        currentWebViewTransitionByTabID[tabID] == token
    }

    // MARK: - Activation/Deactivation
    func requestDeactivateWebView(tabID: UUID, mode: SafariLikeCoreKit.TabRegistry.WebViewDetachMode, reason: String) {
        let hasLiveHandle = manager.currentTabRegistry.existingStore(for: tabID)?.webViewHandle?.isAlive == true
        let hasInFlight = manager.tabTasks.hasAnyTask(
            tabID: tabID,
            keys: Set([.ensureLoaded, .bindActiveTab, .renderBudgetActivate, .splitCompanionActivate, .scrollRestore])
        )
        if hasLiveHandle == false, hasInFlight == false {
            manager.recordWebViewDebug("[WebViewTx] deactivate.noop tab=\(tabID.uuidString) reason=\(reason)")
            return
        }

        _ = beginWebViewTransition(reason: "deactivate.\(reason)", tabID: tabID)
        manager.tabTasks.cancelTask(tabID: tabID, key: .ensureLoaded)
        manager.tabTasks.cancelTask(tabID: tabID, key: .renderBudgetActivate)
        manager.tabTasks.cancelTask(tabID: tabID, key: .splitCompanionActivate)
        manager.tabTasks.cancelTask(tabID: tabID, key: .scrollRestore)

        manager.currentTabRegistry.deactivateWebView(tabID: tabID, mode: mode)
    }

    func activateRuntimeStore(
        tabID: UUID,
        role: SafariLikeCoreKit.TabWebStore.Role = .primary,
        protectedTabIDs: Set<UUID>,
        token: UInt64,
        reason: String
    ) async -> SafariLikeCoreKit.TabWebStore? {
        guard isCurrentWebViewTransition(tabID: tabID, token: token) else {
            manager.recordWebViewDebug("[WebViewTx] activate.stale.pre tab=\(tabID.uuidString) tx=\(token) reason=\(reason)")
            return nil
        }
        if let existing = manager.currentTabRegistry.existingStore(for: tabID), existing.webViewHandle?.isAlive == true {
            manager.recordWebViewDebug("[WebViewTx] activate.noop.alreadyAlive tab=\(tabID.uuidString) tx=\(token) reason=\(reason)")
            return existing
        }
        guard let runtime = manager.runtime(for: tabID, role: role) else {
            RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
            return nil
        }
        let store = await runtime.activate(protectedTabIDs: protectedTabIDs)
        guard isCurrentWebViewTransition(tabID: tabID, token: token) else {
            manager.recordWebViewDebug("[WebViewTx] activate.stale.post tab=\(tabID.uuidString) tx=\(token) reason=\(reason)")
            return nil
        }
        return store
    }

    func loadURLStringInBackgroundTab(tabID: UUID, urlString: String, reason: String) {
        manager.tabTasks.replaceTask(tabID: tabID, key: .ensureLoaded) {
            Task { @MainActor [weak manager] in
                guard let manager else { return }
                guard manager.sessionStore.tabs.contains(where: { $0.id == tabID }) else { return }

                var protected: Set<UUID> = []
                if manager.isSplitViewEnabled {
                    if let left = manager.leftTabID { protected.insert(left) }
                    if let right = manager.rightTabID { protected.insert(right) }
                }

                let token = manager.beginWebViewTransition(reason: "ensureLoaded.\(reason)", tabID: tabID)
                guard let store = await manager.activateRuntimeStore(
                    tabID: tabID,
                    role: .primary,
                    protectedTabIDs: protected,
                    token: token,
                    reason: reason
                ) else { return }

                guard manager.isCurrentWebViewTransition(tabID: tabID, token: token) else { return }
                let navigation = manager.navigationService ?? NavigationService(tabManager: manager)
                navigation.loadURLString(urlString, in: store, force: true)
            }
        }
    }

    func forceAttachActiveTabWebView(reason: String) {
        manager.normalTabRegistry.setActivationSuppressed(false)
        manager.privateTabRegistry.setActivationSuppressed(false)
        guard let id = manager.activeTabID else { return }
        manager.runtimeContextIfAvailable?.attachmentCoordinator.requestRuntimeStateOverride(tabID: id, desired: .attaching)
        manager.recordWebViewWarning("FORCE-ATTACH requested (tabID=\(id.uuidString)) reason=\(reason)")
        manager.tabCoordinator.activateTab(id)
        manager.lifecycleController.applyRenderBudget(reason: "tab.forceAttach")
    }

    func activateCompanionPaneIfNeeded(tabID: UUID) {
        Task { @MainActor [weak manager] in
            guard let manager else { return }
            guard manager.state.isTabOverviewVisible == false else { return }
            guard manager.sessionStore.tabs.contains(where: { $0.id == tabID }) else { return }

            // Ensure CoreKit is the single authority for whether this tab may be live.
            manager.reconcileRenderVisibilityPolicy(reason: "activateCompanionPane")
            if let core = manager.runtimeContextIfAvailable?.core,
               core.tabPageLifecycleState(tabID: tabID) != .liveAttached {
                manager.recordWebViewDebug("[WebViewTx] companion.suppressedByCore tab=\(tabID.uuidString)")
                return
            }

            var protected: Set<UUID> = []
            if manager.isSplitViewEnabled {
                if let left = manager.leftTabID { protected.insert(left) }
                if let right = manager.rightTabID { protected.insert(right) }
            }

            let webTx = manager.beginWebViewTransition(reason: "activateCompanionPane", tabID: tabID)
            guard let store = await manager.activateRuntimeStore(
                tabID: tabID,
                role: .companion,
                protectedTabIDs: protected,
                token: webTx,
                reason: "activateCompanionPane"
            ) else { return }

            guard manager.isCurrentWebViewTransition(tabID: tabID, token: webTx) else { return }
            manager.setLifecycle(tabID: tabID, lifecycle: .active, runtimeAttachment: .attached)

            if let current = store.state.currentURL?.absoluteString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased(),
               current.isEmpty == false,
               current != "about:blank" {
                return
            }

            let preferredURL = manager.sessionStore.tabs.first(where: { $0.id == tabID })?.urlString
            let trimmed = preferredURL?.trimmingCharacters(in: .whitespacesAndNewlines)
            let url = (trimmed?.isEmpty == false ? trimmed : nil) ?? manager.defaultHomeURLString
            let navigation = manager.navigationService ?? NavigationService(tabManager: manager)
            guard manager.isCurrentWebViewTransition(tabID: tabID, token: webTx) else { return }
            navigation.loadURLString(url, in: store, force: true)
        }
    }
}

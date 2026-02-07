import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
final class TabLifecycleController {
    weak var manager: TabManager?
    private var tabSelectionCancellable: AnyCancellable?
    init(manager: TabManager) {
        self.manager = manager
        // Ensure selection binding is installed early so WebView rendering can bind
        // as soon as sessionStore.selectedTabID changes.
        bindSessionSelection(for: manager.currentSessionStore)
    }
    @MainActor
    func rebuildTabsFromSessionAndEnsureSelection(preferredActiveID: UUID? = nil) {
        guard let manager else {
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before rebuildTabsFromSessionAndEnsureSelection",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
            return
        }
        // Determine active tab
        var activeID: UUID? = preferredActiveID
            ?? manager.currentSessionStore.selectedTabID
            ?? manager.currentSessionStore.tabs.first?.id
        if activeID == nil {
            // No tabs in the session store yet; create a tab and select it.
            activeID = manager.newTab(inBackground: false)
        }
        if let activeID {
            manager.selectTab(activeID)
        }
    }
    @MainActor
    func bindSessionSelection(for store: BrowserSessionStore) {
        guard let manager else {
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before bindSessionSelection",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
            return
        }
        tabSelectionCancellable?.cancel()
        tabSelectionCancellable = store.$selectedTabID
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak manager] selectedID in
                guard let manager else { return }
                // เลือก id ที่ถูกต้อง
                let resolvedID: UUID? = {
                    if let selectedID, store.tabs.contains(where: { $0.id == selectedID }) {
                        return selectedID
                    }
                    return store.tabs.first?.id
                }()
                if let id = resolvedID {
                    manager.selectTab(id)
                }
            }
    }
    @MainActor
    func enableSplitView() {
        guard let manager else {
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before enableSplitView",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
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
        // Render policy (budget + visibility) is computed/applied centrally.
        applyRenderBudget(reason: "split.enabled")
    }
    @MainActor
    func disableSplitView() {
        guard let manager else {
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before disableSplitView",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
            return
        }
        let previousRightTabID = manager.rightTabID
        manager.isSplitViewEnabled = false
        manager.activePane = .left
        manager.rightTabID = nil
        if manager.leftTabID == nil {
            manager.leftTabID =
                manager.currentSessionStore.selectedTabID
                ?? manager.activeTabID
                ?? manager.currentSessionStore.tabs.first?.id
        }
        // When split is disabled there is only one visible pane.
        // Ensure any previously-secondary tab is rebound to primary so activation uses the primary pane context.
        if let previousRightTabID {
            manager.assignTab(previousRightTabID, to: .primary)
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
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before applyRenderBudget(reason=\(reason))",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
            return
        }
        // Single source of truth: compute + apply in TabManager.
        manager.reconcileRenderVisibilityPolicy(reason: reason)
    }
    @MainActor
    func unbindActiveStore(cancelBindTask: Bool = false) {
        guard let manager else {
            Diagnostics.logError(
                "[TabLifecycleController] manager deallocated before unbindActiveStore",
                subsystem: .runtime,
                category: "TabLifecycle"
            )
            return
        }
        manager.unbindActiveStore(cancelBindTask: cancelBindTask)
        manager.activeBindingState = .unbound
    }
}

import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
import SwiftUI

@MainActor
extension SplitBrowserViewModel {
    // MARK: Tabs/Layout glue
    typealias ActivePane = TabManager.ActivePane

    var activePane: ActivePane {
        get { tabManager.activePane }
        set { tabManager.activePane = newValue }
    }

    var isSplitViewEnabled: Bool {
        get { tabManager.isSplitViewEnabled }
        set { tabManager.isSplitViewEnabled = newValue }
    }

    var leftTabID: UUID? { tabManager.leftTabID }
    var rightTabID: UUID? { tabManager.rightTabID }

    var splitViewRatio: CGFloat {
        get { tabManager.splitViewRatio }
        set { tabManager.splitViewRatio = newValue }
    }

    // MARK: Layout API
    var isSplit: Bool { layout.isSplit }

    /// Toggle split intent (single source of truth: chrome.splitViewMode).
    /// Must not be coupled to keyboard or omnibox focus.
    func toggleSplit() {
        chrome.splitViewMode = (chrome.splitViewMode == .single) ? .dual : .single
    }

    func switchPane() { layout.switchPane() }
    func selectLeftPane() { layout.selectLeftPane() }
    func selectRightPane() { layout.selectRightPane() }

    // MARK: Legacy split toggles (compat)
    func toggleSplitView() { toggleSplit() }

    /// Ensures split view never enters an invalid state that would render an empty/ghost pane.
    /// When split is enabled, we must always have two distinct tab IDs.
    func ensureSplitViewInvariantsIfNeeded() {
        guard isSplitViewEnabled else { return }
        // Ensure the left pane is always anchored to a real tab.
        let primaryTabID = tabManager.leftTabID
            ?? tabManager.activeTabID
            ?? activeTabID
            ?? tabManager.newTab(inBackground: false)
        if tabManager.leftTabID != primaryTabID {
            tabManager.leftTabID = primaryTabID
            tabManager.assignTab(primaryTabID, to: .primary)
        }
        // Ensure the right pane exists and is distinct.
        let leftID = tabManager.leftTabID
        if tabManager.rightTabID == nil || tabManager.rightTabID == leftID {
            let secondaryTabID = tabManager.newTab(inBackground: true)
            tabManager.assignTab(secondaryTabID, to: .secondary)
            tabManager.rightTabID = secondaryTabID
        }
    }
}

@MainActor
extension SplitBrowserViewModel {
    // MARK: Tabs/Navigation
    var activeStore: SafariLikeCoreKit.TabWebStore? { tabManager.activeStore }
    var leftPaneStore: SafariLikeCoreKit.TabWebStore? { tabManager.leftPaneStore }
    var rightPaneStore: SafariLikeCoreKit.TabWebStore? { tabManager.rightPaneStore }

    func runtimeStoreIfAlive(for tabID: UUID) -> SafariLikeCoreKit.TabWebStore? { tabManager.runtimeStoreIfAlive(for: tabID) }

    var aliveRuntimeTabIDs: [UUID] { tabManager.aliveRuntimeTabIDs }

    // MARK: Session/Tabs glue
    var sessionStore: BrowserSessionStore { windowCoordinator.sessionStore }

    var activeTabID: UUID? {
        get { sessionStore.selectedTabID }
        set { if let newValue = newValue { windowCoordinator.selectTab(newValue) } }
    }

    /// True when the active tab is in the native Start Page state.
    var isStartPageActiveTab: Bool {
        guard let tabID = activeTabID else { return false }
        guard let tab = sessionStore.tabs.first(where: { $0.id == tabID }) else { return false }
        if case .startPage = tab.state { return true }
        return false
    }

    var tabs: [BrowserTab] {
        tabManager.tabs.map {
            BrowserTab(
                id: $0.id,
                title: $0.title ?? BrowserConstants.UI.newTabTitle,
                urlString: $0.url?.absoluteString ?? "about:blank",
                lastVisitedAt: $0.lastActiveAt
            )
        }
    }

    /// Recovery: If activeStore is nil but activeTabID exists, try to rebind the active tab.
    @MainActor
    func recoverIfActiveStoreMissing() {
        if activeStore == nil, let id = activeTabID {
            tabManager.selectTab(id)
        }
    }

    // MARK: Tabs API
    func openTab(urlString: String? = nil, inBackground: Bool = false) {
        _ = createTab(urlString: urlString, inBackground: inBackground)
    }

    @discardableResult
    func openTabReturningID(urlString: String? = nil, inBackground: Bool = false) -> UUID {
        return createTab(urlString: urlString, inBackground: inBackground)
    }

    @discardableResult
    private func createTab(urlString: String?, inBackground: Bool) -> UUID {
        let newTabID = tabManager.newTab(inBackground: inBackground)
        let trimmedURLString = urlString?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedURLString, trimmedURLString.isEmpty == false {
            // Update session metadata regardless of foreground/background.
            sessionStore.updateTab(id: newTabID, title: nil, urlString: trimmedURLString)
            if inBackground {
                // Background tabs must not steal selection; load directly into the new tab's store.
                tabManager.loadURLStringInBackgroundTab(tabID: newTabID, urlString: trimmedURLString, reason: "vm.backgroundCreate")
            } else {
                // Foreground: selection already moved to the new tab; normal navigation applies.
                navigationService.loadURLString(trimmedURLString, force: true)
            }
        }
        return newTabID
    }

    func newTab(inGroup groupID: UUID? = nil) {
        _ = windowCoordinator.newTab(inGroup: groupID, inBackground: false)
    }

    func newTab() {
        _ = windowCoordinator.newTab(inGroup: nil, inBackground: false)
    }

    func selectTab(_ id: UUID) {
        windowCoordinator.selectTab(id)
    }

    func updateTab(id: UUID, title: String? = nil, urlString: String? = nil) {
        sessionStore.updateTab(id: id, title: title, urlString: urlString)
    }

    func closeTab(_ id: UUID) {
        Task { @MainActor in
            await windowCoordinator.closeTab(id)
        }
    }

    func removeAllTabs() {
        // Best-effort: close all tabs via session store + registry.
        let ids = sessionStore.snapshotTabIDs()
        Task { @MainActor in
            for id in ids {
                await windowCoordinator.closeTab(id)
            }
        }
    }

    func createTabGroup(name: String, color: BrowserTabGroup.TabGroupColor? = nil) {
        _ = sessionStore.createTabGroup(name: name, color: color ?? .blue)
    }

    func selectTabGroup(_ id: UUID?) { sessionStore.selectTabGroup(id: id) }
    func deleteTabGroup(_ id: UUID) { sessionStore.deleteTabGroup(id: id) }

    func updateTabGroup(
        id: UUID,
        name: String,
        color: BrowserTabGroup.TabGroupColor? = nil
    ) {
        sessionStore.updateTabGroup(id: id, name: name, color: color)
    }

    func addTabToGroup(tabID: UUID, groupID: UUID) {
        sessionStore.addTabToGroup(tabID: tabID, groupID: groupID)
    }

    // MARK: Tabs lifecycle
    /// Handle a tab close event (replacing the old onTabClosed handler).
    func handleTabClosed(_ id: TabID) {
        Task { @MainActor in
            await windowCoordinator.closeTab(id)
            if sessionStore.tabs.isEmpty {
                _ = windowCoordinator.newTab(inGroup: nil, inBackground: false)
            }
        }
    }

    /// Reorder tabs via central API to keep domains store-agnostic.
    func moveTab(from: Int, to: Int) {
        windowCoordinator.moveTab(from: from, to: to)
    }
}

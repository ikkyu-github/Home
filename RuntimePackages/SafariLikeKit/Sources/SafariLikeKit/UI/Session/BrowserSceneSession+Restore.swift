import Foundation
import SafariLikeCoreKit
@MainActor
extension BrowserSceneSession {
    // MARK: - Bootstrap / Restore (Public)
    public func restoreInitialPersistedStateIfAvailable() async {
        viewModel.tabManager.beginSessionRestoreTracingIfNeeded(sceneID: sceneID)
        // Phase A (Immediate): BrowserSessionStore is the single persisted source of truth.
        await viewModel.sessionStore.awaitInitialLoad()
        applyPersistedWindowSessionState()
        viewModel.tabManager.markSessionRestorePhaseAUIReady(source: "BrowserSessionStore")
    }
    // MARK: - Single source of truth restore
    private func applyPersistedWindowSessionState() {
        let store = viewModel.sessionStore
        let tabManager = viewModel.tabManager
        // UI flags.
        viewModel.windowSession.sidebarMode = store.uiState.isSidebarVisible
            ? .visible(content: .menu)
            : .hidden
        viewModel.isRelatedVisible = store.uiState.isRelatedVisible
        // Split/layout.
        let split = store.splitViewState
        viewModel.isSplitViewEnabled = split.isEnabled
        chrome.splitViewMode = split.isEnabled ? .dual : .single
        viewModel.splitViewRatio = CGFloat(split.ratio)
        viewModel.activePane = (split.activePane == .right) ? .right : .left
        let allIDs = Set(store.tabs.map { $0.id })
        let selected = store.selectedTabID.flatMap { allIDs.contains($0) ? $0 : nil } ?? store.tabs.first?.id
        if split.isEnabled {
            let left = split.leftTabID.flatMap { allIDs.contains($0) ? $0 : nil } ?? selected
            let right = split.rightTabID.flatMap { allIDs.contains($0) ? $0 : nil }
                ?? store.tabs.first(where: { $0.id != left })?.id
                ?? selected
            tabManager.isSplitViewEnabled = true
            tabManager.applyRestoredSplitTabIDs([left, right].compactMap { $0 })
            if let selected { tabManager.activeTabID = selected }
        } else {
            tabManager.isSplitViewEnabled = false
            if let selected {
                tabManager.activeTabID = selected
            }
        }
    }
}

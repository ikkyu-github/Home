import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
import SafariLikeUXKit
import SwiftUI
import UIKit

// MARK: - Fault Recovery
@MainActor
extension SplitBrowserViewModel {
    func requestUIRerender() {
        mutateAsync {
            self.uiRerenderNonce = UUID()
        }
    }
}

// MARK: - Spin View (Split close)
@MainActor
extension SplitBrowserViewModel {
    func openSpinViewIfPossible() {
        guard isSplitViewEnabled == false else { return }
        // Boot race guard: during launch, session restore may not have produced an activeTabID yet.
        // Ensure a primary tab exists so SpinView can open deterministically.
        let primaryTabID = activeTabID
        ?? tabManager.activeTabID
        ?? tabManager.newTab(inBackground: false)
        // Ensure the left pane is anchored to the primary tab.
        if tabManager.leftTabID == nil {
            tabManager.leftTabID = primaryTabID
            tabManager.assignTab(primaryTabID, to: .primary)
        }
        // Create a secondary tab if needed.
        if tabManager.rightTabID == nil {
            let secondaryTabID = tabManager.newTab(inBackground: true)
            tabManager.assignTab(secondaryTabID, to: .secondary)
            tabManager.rightTabID = secondaryTabID
            // Best-effort: inherit URL from the primary tab so split opens with similar context.
            let inheritedURLString: String? = {
                if let url = activeStore?.state.currentURL?.absoluteString {
                    return url
                }
                return sessionStore.tabs.first(where: { $0.id == primaryTabID })?.urlString
            }()
            if let inheritedURLString, !inheritedURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sessionStore.updateTab(id: secondaryTabID, urlString: inheritedURLString)
            }
        }
        // Enable split first so pane resolution for the right tab is treated as `.secondary`.
        isSplitViewEnabled = true
        activePane = .left
        let rightID = tabManager.rightTabID
        let leftID = tabManager.leftTabID
        // NOTE: Do not activate/prewarm WKWebView from the ViewModel.
        // Activation is driven by TabManager/TabLifecycleController and budgeted via TabRegistry.
        _ = rightID
        _ = leftID
    }

    func closeSpinView() {
        // Stop and detach the secondary pane WebView before clearing split assignment.
        // Detach must go through TabRegistry to keep budget/LRU tracking consistent.
        if let secondaryStore = tabManager.rightPaneStore {
            secondaryStore.stopLoading()
        }
        if let secondaryTabID = tabManager.rightTabID {
            tabManager.requestDeactivateWebView(tabID: secondaryTabID, mode: .warm, reason: "split.close")
        }
        isSplitViewEnabled = false
        activePane = .left
        // cleanup (best-effort)
        if let left = tabManager.leftTabID ?? tabManager.activeTabID {
            tabManager.applyRestoredSplitTabIDs([left])
        } else {
            tabManager.applyRestoredSplitTabIDs([])
        }
    }
}

@MainActor
extension SplitBrowserViewModel {
    var activeURLString: String? { activeStore?.state.currentURL?.absoluteString }

    // MARK: Navigation API
    func open(_ url: URL) {
        Task { @MainActor in
            await windowCoordinator.openURL(url, force: false)
        }
    }

    func reload() { windowCoordinator.reload() }
    func goBack() { windowCoordinator.goBack() }
    func goForward() { windowCoordinator.goForward() }
    func openExternalURL(_ url: URL) { bar.openExternalURL(url) }

    // MARK: AddressBar API (state-driven; dispatch events only)
    var addressText: String { bar.addressText }
    var isAddressFocusedExternally: Bool { bar.isAddressFocusedExternally }
    func requestAddressFocus() { bar.requestAddressFocus() }
    func submitAddress() { bar.submitAddress() }
    func updateSuggestions(query: String) { bar.updateSuggestions(query: query) }
    func clearSuggestions() { bar.clearSuggestions() }
    func applySuggestion(_ suggestion: OmniboxSuggestion) { bar.applySuggestion(suggestion) }
    func loadSearch(query: String) { bar.loadSearch(query: query) }

    // MARK: Search engine config
    func updateSearchEngineURL(_ url: String) {
        guard let engineURL = URL(string: url) else { return }
        normalTabRegistry.updateSearchEngineURL(engineURL)
        privateTabRegistry.updateSearchEngineURL(engineURL)
    }
}

// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (ViewModel extension imports SwiftUI/UIKit; high rebuild fan-out).
// Keep this file focused on glue API; avoid pulling in additional frameworks.
@MainActor
extension SplitBrowserViewModel {
    var contentBlockerManager: (any ContentBlockingProviding)? { contentBlockerManagerInstance }

    // MARK: - View Intents (UI -> ViewModel)
    /// Intent: explicitly set sidebar visibility.
    /// Views should call this instead of touching WindowCoordinator directly.
    func setSidebarVisible(_ isVisible: Bool) {
        if isVisible {
            windowCoordinator.setSidebarMode(.visible(content: sidebarContent))
        } else {
            windowCoordinator.setSidebarMode(.hidden)
        }
    }

    /// Intent: handle a sidebar menu selection.
    func handleSidebarSelection(_ item: SidebarView.Item) {
        glue.handleSidebarSelect(item)
    }

    /// Intent: trigger the post-first-frame load of the active tab.
    func loadActiveTabContentAfterUIReady() async {
        await windowCoordinator.loadActiveTabContentAfterUIReady()

        let activeTabURLString: String = {
            let id = activeTabID ?? sessionStore.selectedTabID
            guard let id else { return "" }
            return sessionStore.tabs.first(where: { $0.id == id })?.urlString ?? ""
        }()

        let normalized = activeTabURLString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty || normalized == "about:blank" {
            await windowCoordinator.openURLString(defaultHomeURLString, force: false)
        }
    }

    /// Intent: set active pane (split focus).
    func setActivePane(_ pane: ActivePane) {
        tabManager.activePane = pane
    }

    /// Intent: set Tab Overview visibility.
    /// This centralizes the mutation boundary so Views avoid writing @Published state directly.
    func setTabOverviewVisible(_ isVisible: Bool) {
        mutateAsync {
            self.isTabOverviewVisible = isVisible
        }
    }

    /// Intent: mirror Related chrome visibility back into the ViewModel (persistence/journaling).
    /// This must not set user override flags.
    func syncRelatedVisibilityFromChrome(_ isVisible: Bool) {
        mutateAsync {
            self.isRelatedVisible = isVisible
        }
    }

    /// Intent: explicitly set companion visibility.
    func setCompanionVisible(_ isVisible: Bool) {
        mutateAsync {
            self.isCompanionVisible = isVisible
        }
    }

    /// Intent: update landscape-related flags from layout policy.
    func setLandscapeFlags(isLandscapeDevice: Bool, isLandscapeSplitActive: Bool) {
        mutateAsync {
            self.isLandscapeDevice = isLandscapeDevice
            self.isLandscapeSplitActive = isLandscapeSplitActive
        }
    }

    /// Intent: keep reducer snapshot state in sync with UI-facing flags.
    func syncAutoCompanionEnabledToState() {
        mutateAsync {
            self.state.isAutoCompanionEnabled = self.isAutoCompanionEnabled
        }
    }

    /// Runtime mirror: keep the runtime tab manager in sync with the UI overview visibility.
    func syncTabOverviewVisibilityToRuntime(_ isVisible: Bool) {
        tabManager.setTabOverviewVisible(isVisible)
    }

    /// Runtime mirror: update strict render-budgeting based on presentation progress.
    func syncTabOverviewPresentationProgressToRuntime(_ progress: CGFloat) {
        if tabManager.hasActivatedInitialVisiblePanes == false {
            tabManager.setTabOverviewVisible(false)
            return
        }
        // Treat any non-zero progress as "overview visible" for strict render budgeting.
        tabManager.setTabOverviewVisible(progress > 0.001)
    }

    /// Runtime mirror: update metrics used by runtime policy.
    func updateVisiblePaneMetrics(containerSize: CGSize, safeAreaInsets: CGSize) {
        tabManager.updateVisiblePaneMetrics(containerSize: containerSize, safeAreaInsets: safeAreaInsets)
    }

    // MARK: Glue API (delegations)
    func toggleSidebar() {
        if isSidebarVisible {
            windowCoordinator.setSidebarMode(.hidden)
        } else {
            windowCoordinator.setSidebarMode(.visible(content: sidebarContent))
        }
    }

    func showSidebar(content: SidebarContent) {
        windowCoordinator.setSidebarMode(.visible(content: content))
    }

    func presentTabOverview() {
        guard chrome.uxPolicy.tabOverview.isEnabled else { return }
        mutateAsync {
            self.isTabOverviewVisible = true
        }
    }

    func dismissTabOverview() {
        mutateAsync {
            self.isTabOverviewVisible = false
        }
    }

    func handleWebScroll(contentOffset: CGPoint, scrollView: UIScrollView) {
        glue.handleWebScroll(contentOffset: contentOffset, scrollView: scrollView)
    }

    // MARK: Actions
    func send(_ action: BrowserAction) {
        switch action {
        case .newTab(let urlString, let inBackground):
            openTab(urlString: urlString, inBackground: inBackground)
        case .closeTab(let id):
            closeTab(id)
        case .selectTab(let id):
            selectTab(id)
        case .openURLString(let urlString):
            let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            Task { @MainActor in
                await windowCoordinator.openURLString(trimmed, force: false)
            }
        case .openURLStringForce(let urlString):
            Task { @MainActor in
                await windowCoordinator.openURLString(urlString, force: true)
            }
        case .goBack:
            windowCoordinator.goBack()
        case .goForward:
            windowCoordinator.goForward()
        case .reload:
            windowCoordinator.reload()
        case .showTabOverview(let isVisible):
            setTabOverviewVisible(isVisible)
        case .setSplitViewEnabled(let isEnabled):
            if isEnabled {
                openSpinViewIfPossible()
            } else {
                closeSpinView()
            }
        case .forceAttachWebView:
            tabManager.forceAttachActiveTabWebView(reason: "ui.forceAttachWebView")
        case .stopLoading:
            browserActions.stopLoading()
        case .shareCurrentPage:
            shareCoordinator.shareCurrentPageLink(from: self)
        case .openCompanion:
            companion.openBookmarks()
        case .closeCompanion:
            companion.closeCompanion()
        case .toggleRelated:
            // User intent: becomes the explicit override signal.
            // Policy may still decide presentation style, but visibility is intent-driven.
            mutateAsync {
                self.didUserOverrideCompanionVisibility = true
                self.isRelatedVisible.toggle()
                #if DEBUG
                print(
                    "[Related][Intent] toggleRelated -> isRelatedVisible=\(self.isRelatedVisible) activeTabID=\(String(describing: self.activeTabID)) selectedTabID=\(String(describing: self.sessionStore.selectedTabID)) isLandscapeDevice=\(self.isLandscapeDevice)"
                )
                #endif
            }
        case .setRelatedVisible(let isVisible):
            // Used by drag-to-close and scrim taps to avoid double-toggling.
            mutateAsync {
                self.didUserOverrideCompanionVisibility = true
                self.isRelatedVisible = isVisible
                #if DEBUG
                print(
                    "[Related][Intent] setRelatedVisible(\(isVisible)) -> isRelatedVisible=\(self.isRelatedVisible) activeTabID=\(String(describing: self.activeTabID)) selectedTabID=\(String(describing: self.sessionStore.selectedTabID)) isLandscapeDevice=\(self.isLandscapeDevice)"
                )
                #endif
            }
        default:
            break
        }
    }
}

@MainActor
extension SplitBrowserViewModel {
    // MARK: Companion API
    func toggleCompanion() { companion.toggleCompanion() }
    func applyOrientationRule(isLandscape: Bool) { companion.applyOrientationRule(isLandscape: isLandscape) }
    func openBookmarks() { companion.openBookmarks() }
    func openHistory() { companion.openHistory() }
    func openDownloads() { companion.openDownloads() }
    func closeCompanion() { companion.closeCompanion() }
    func destroyRightPaneForRoot() { companion.destroyRightPaneForRoot() }
    func resetCompanionOverride() { companion.resetCompanionOverride() }
    func openCompanionItem(_ item: CompanionItem) { companion.openCompanionItem(item) }
    func openCompanionItemInNewTab(_ item: CompanionItem) { companion.openCompanionItemInNewTab(item) }

    // MARK: Website settings & share helpers that conceptually live with companion actions
    func addBookmarkForActivePage() { glue.addBookmarkForActivePage() }
    func addToReadingListForActivePage() { glue.addToReadingListForActivePage() }
}

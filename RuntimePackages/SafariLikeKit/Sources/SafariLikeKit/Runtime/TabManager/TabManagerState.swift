import Foundation
import CoreGraphics
import SafariLikeCoreKit
// MARK: - Pure State
struct TabManagerState: Equatable {
    // MARK: Tabs
    var tabs: [TabState]
    /// The last tab ID selected by the user/UI.
    ///
    /// Note: the runtime binding layer uses BrowserSessionStore + TabCoordinator
    /// as the source of truth for active WebKit store binding.
    var activeTabID: UUID?
    // MARK: Tab Overview
    /// When true, the UI is in (or transitioning into) tab overview.
    /// Safari freezes all webviews in overview for smooth scrolling.
    var isTabOverviewVisible: Bool = false
    // MARK: Split View
    var splitViewState: SplitViewState
    struct SplitViewState: Equatable {
        var isEnabled: Bool
        var activePane: TabManager.ActivePane
        var leftTabID: UUID?
        var rightTabID: UUID?
        var ratio: CGFloat
        init(
            isEnabled: Bool = false,
            activePane: TabManager.ActivePane = .left,
            leftTabID: UUID? = nil,
            rightTabID: UUID? = nil,
            ratio: CGFloat = 0.5
        ) {
            self.isEnabled = isEnabled
            self.activePane = activePane
            self.leftTabID = leftTabID
            self.rightTabID = rightTabID
            self.ratio = ratio
        }
    }
    // MARK: Mode
    var isPrivateMode: Bool
    // MARK: Tab Groups
    /// Tab groups are currently managed by BrowserSessionStore; this is a lightweight
    /// snapshot placeholder for reducer-style state.
    var tabGroups: [BrowserTabGroup]
    init(
        tabs: [TabState] = [],
        activeTabID: UUID? = nil,
        splitViewState: SplitViewState = .init(),
        isPrivateMode: Bool = false,
        tabGroups: [BrowserTabGroup] = [],
        isTabOverviewVisible: Bool = false
    ) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.splitViewState = splitViewState
        self.isPrivateMode = isPrivateMode
        self.tabGroups = tabGroups
        self.isTabOverviewVisible = isTabOverviewVisible
    }
}

import Foundation
import SafariLikeCoreKit
extension TabManager {
    struct State {
        var tabs: [Tab]
        var selectedTabId: UUID?
        var isSplitViewEnabled: Bool
        var tabGroups: [TabGroup]
        var activeTabGroupId: UUID?
        var isPrivateMode: Bool
        var isTabOverviewPresented: Bool
        var error: TabManagerError?
        init(
            tabs: [Tab] = [],
            selectedTabId: UUID? = nil,
            isSplitViewEnabled: Bool = false,
            tabGroups: [TabGroup] = [],
            activeTabGroupId: UUID? = nil,
            isPrivateMode: Bool = false,
            isTabOverviewPresented: Bool = false,
            error: TabManagerError? = nil
        ) {
            self.tabs = tabs
            self.selectedTabId = selectedTabId
            self.isSplitViewEnabled = isSplitViewEnabled
            self.tabGroups = tabGroups
            self.activeTabGroupId = activeTabGroupId
            self.isPrivateMode = isPrivateMode
            self.isTabOverviewPresented = isTabOverviewPresented
            self.error = error
        }
    }
}

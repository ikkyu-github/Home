import Foundation
import SafariLikeCoreKit
extension TabManager {
    // MARK: - Reducer
    public func reduce(state: inout TabManager.State, action: Actions) {
        switch action {
        case .open:
            // Open tab logic
            break
        case .reload:
            // Reload logic
            break
        case .goBack:
            // Go back logic
            break
        case .goForward:
            // Go forward logic
            break
        case .openExternalURL:
            // External URL logic
            break
        case .requestAddressFocus:
            // Focus address bar logic
            break
        case .submitAddress:
            // Submit address logic
            break
        case .updateSuggestions:
            // Update suggestions logic
            break
        case .clearSuggestions:
            // Clear suggestions logic
            break
        case .applySuggestion:
            // Apply suggestion logic
            break
        case .loadSearch:
            // Load search logic
            break
        case .toggleSplit:
            state.isSplitViewEnabled.toggle()
        case .switchPane:
            // Switch pane logic
            break
        case .selectLeftPane:
            // Select left pane logic
            break
        case .selectRightPane:
            // Select right pane logic
            break
        case .togglePrivateMode:
            state.isPrivateMode.toggle()
        case .newTab:
            // New tab logic
            break
        case .selectTab(let tabId):
            state.selectedTabId = tabId
        case .closeTab(let tabId):
            state.tabs.removeAll { $0.id == tabId }
            if state.selectedTabId == tabId {
                state.selectedTabId = state.tabs.first?.id
            }
        case .removeAllTabs:
            state.tabs.removeAll()
            state.selectedTabId = nil
        case .createTabGroup:
            // Create tab group logic
            break
        case .selectTabGroup(let groupId):
            state.activeTabGroupId = groupId
        case .deleteTabGroup(let groupId):
            state.tabGroups.removeAll { $0.id == groupId }
            if state.activeTabGroupId == groupId {
                state.activeTabGroupId = state.tabGroups.first?.id
            }
        case .updateTabGroup:
            // Update tab group logic
            break
        case .addTabToGroup:
            // Add tab to group logic
            break
        case .presentTabOverview:
            state.isTabOverviewPresented = true
        case .dismissTabOverview:
            state.isTabOverviewPresented = false
        case .showError(let error):
            state.error = error
        }
    }
}

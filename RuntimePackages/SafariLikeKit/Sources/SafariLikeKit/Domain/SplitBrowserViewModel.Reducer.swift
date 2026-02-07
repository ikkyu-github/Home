import Foundation
import SafariLikeCoreKit
extension SplitBrowserViewModel {
    // MARK: - Reducer
    public func reduce(state: inout State, action: Actions) {
        switch action {
            case .openCompanion,
                 .closeCompanion,
                 .history,
                 .settings:
                break // no-op, handled by CompanionDomain
        case .toggleSidebar:
            state.isSidebarVisible.toggle()
        case .showSidebar(let content):
            state.sidebarContent = content
            state.isSidebarVisible = true
        case .presentTabOverview:
            state.isTabOverviewPresented = true
        case .dismissTabOverview:
            state.isTabOverviewPresented = false
        case .handleWebScroll(let contentOffset, let scrollView):
            _ = (contentOffset, scrollView); break // UI logic only
        case .open(let url):
            _ = url; break // Navigation logic only
        case .reload:
            break
        case .goBack:
            break
        case .goForward:
            break
        case .openExternalURL(let url):
            _ = url; break
        case .requestAddressFocus:
            break
        case .submitAddress:
            break
        case .updateSuggestions(let query):
            // Example: state.suggestions = ...
            _ = query; break
        case .clearSuggestions:
            state.suggestions = []
        case .applySuggestion(let suggestion):
            _ = suggestion; break
        case .loadSearch(let query):
            _ = query; break
        case .toggleSplit:
            break
        case .switchPane:
            break
        case .selectLeftPane:
            break
        case .selectRightPane:
            break
        case .togglePrivateMode:
            state.isPrivateMode.toggle()
        case .newTab(let inGroup):
            _ = inGroup; break
        case .selectTab(let id):
            _ = id; break
        case .closeTab(let id):
            _ = id; break
        case .removeAllTabs:
            break
        case .createTabGroup(let name, let color):
            _ = (name, color); break
        case .selectTabGroup(let id):
            _ = id; break
        case .deleteTabGroup(let id):
            _ = id; break
        case .updateTabGroup(let id, let name, let color):
            _ = (id, name, color); break
        case .addTabToGroup(let tabID, let groupID):
            _ = (tabID, groupID); break
        }
    }
}

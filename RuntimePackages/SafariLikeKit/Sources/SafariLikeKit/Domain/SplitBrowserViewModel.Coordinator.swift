import Foundation
import SafariLikeCoreKit
extension SplitBrowserViewModel {
    // MARK: - Coordinator
    public func coordinate(action: Actions) {
        switch action {
        case .toggleSidebar:
            break
        case .showSidebar(let content):
            _ = content; break
        case .presentTabOverview:
            break
        case .dismissTabOverview:
            break
        case .handleWebScroll(let contentOffset, let scrollView):
            _ = (contentOffset, scrollView); break
        case .open(let url):
            _ = url; break
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
            _ = query; break
        case .clearSuggestions:
            break
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
            break
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
        case .openCompanion,
             .closeCompanion,
             .history,
             .settings:
            break
        }
    }
}

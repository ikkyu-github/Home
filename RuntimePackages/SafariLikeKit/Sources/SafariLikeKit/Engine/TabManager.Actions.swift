import Foundation
import SafariLikeCoreKit
extension TabManager {
    public enum Actions {
        case open(URL)
        case reload
        case goBack
        case goForward
        case openExternalURL(URL)
        case requestAddressFocus
        case submitAddress(String)
        case updateSuggestions(String)
        case clearSuggestions
        case applySuggestion(String)
        case loadSearch(String)
        case toggleSplit
        case switchPane
        case selectLeftPane
        case selectRightPane
        case togglePrivateMode
        case newTab
        case selectTab(UUID)
        case closeTab(UUID)
        case removeAllTabs
        case createTabGroup
        case selectTabGroup(UUID)
        case deleteTabGroup(UUID)
        case updateTabGroup(UUID)
        case addTabToGroup(UUID, UUID)
        case presentTabOverview
        case dismissTabOverview
        case showError(TabManagerError)
    }
}

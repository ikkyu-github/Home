import UIKit
import Foundation
import SafariLikeCoreKit
extension SplitBrowserViewModel {
    // MARK: - Actions
    public enum Actions {
        case toggleSidebar
        case showSidebar(content: SidebarContent)
        case presentTabOverview
        case dismissTabOverview
        case handleWebScroll(contentOffset: CGPoint, scrollView: UIScrollView)
        case open(URL)
        case reload
        case goBack
        case goForward
        case openExternalURL(URL)
        case requestAddressFocus
        case submitAddress
        case updateSuggestions(query: String)
        case clearSuggestions
        case applySuggestion(OmniboxSuggestion)
        case loadSearch(query: String)
        case toggleSplit
        case switchPane
        case selectLeftPane
        case selectRightPane
        case togglePrivateMode
        case newTab(inGroup: UUID?)
        case selectTab(UUID)
        case closeTab(UUID)
        case removeAllTabs
        case createTabGroup(name: String, color: BrowserTabGroup.TabGroupColor)
        case selectTabGroup(UUID?)
        case deleteTabGroup(UUID)
        case updateTabGroup(id: UUID, name: String?, color: BrowserTabGroup.TabGroupColor?)
        case addTabToGroup(tabID: UUID, groupID: UUID)
        // Companion-related actions (compatibility)
        case openCompanion
        case closeCompanion
        case history
        case settings
        init?(browserAction: BrowserAction) {
                switch browserAction {
                case .newTab:
                    self = .newTab(inGroup: nil)
                case .closeTab(let id):
                    self = .closeTab(id)
                case .selectTab(let id):
                    self = .selectTab(id)
                case .openURLString(let url):
                    guard let urlObj = URL(string: url) else { return nil }
                    self = .open(urlObj)
                case .openURLStringForce(let url):
                    guard let urlObj = URL(string: url) else { return nil }
                    self = .open(urlObj)
                case .goBack:
                    self = .goBack
                case .goForward:
                    self = .goForward
                case .reload:
                    self = .reload
                default:
                    return nil
                }
        }
    }
}

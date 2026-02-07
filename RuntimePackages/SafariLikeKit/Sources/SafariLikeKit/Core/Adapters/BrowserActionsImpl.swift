import Foundation
import WebKit
import SafariLikeCoreKit
@MainActor
final class BrowserActionsImpl: BrowserActions {
    private let sessionStore: BrowserSessionStore
    private let tabManager: TabManager
    private let navigation: SplitBrowserNavigationDomain
    init(sessionStore: BrowserSessionStore, tabManager: TabManager, navigation: SplitBrowserNavigationDomain) {
        self.sessionStore = sessionStore
        self.tabManager = tabManager
        self.navigation = navigation
    }
    // MARK: - Navigation
    func open(urlString: String) { navigation.openURLString(urlString, force: false) }
    func reload() { navigation.reload() }
    func goBack() { navigation.goBack() }
    func goForward() { navigation.goForward() }
    func stopLoading() { navigation.stopLoading() }
    // MARK: - Tabs
    func newTab() {
        let id = tabManager.newTab()
        tabManager.selectTab(id)
    }
    func closeActiveTab() {
        guard let id = sessionStore.selectedTabID else { return }
        tabManager.closeTab(id)
    }
    func selectTab(id: UUID) { tabManager.selectTab(id) }
}

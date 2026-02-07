import Foundation
import WebKit
import SafariLikeCoreKit
/// Internal implementation of BrowserCoordinator.
/// Orchestrates domain state mutations and navigation flows.
@MainActor
final class BrowserCoordinatorImpl: BrowserCoordinator {
    typealias Domain = BrowserDomainStateImpl
    typealias UI = BrowserUIStateImpl
    let domain: Domain
    let ui: UI
    // MARK: - Navigation Domain Glue
    private let navigationDomain: SplitBrowserNavigationDomain
    // MARK: - Init
    init(domain: Domain, ui: UI, navigationDomain: SplitBrowserNavigationDomain) {
        self.domain = domain
        self.ui = ui
        self.navigationDomain = navigationDomain
    }
    // MARK: - Navigation Actions
    func goBack() {
        navigationDomain.goBack()
    }
    func goForward() {
        navigationDomain.goForward()
    }
    func reload() {
        navigationDomain.reload()
    }
    func stopLoading() {
        navigationDomain.stopLoading()
    }
    // MARK: - Tab Management
    func newTab() {
        let newTabID = domain.activeSessionStore.addTab()
        domain.activeTabID = newTabID
    }
    func closeTab(_ tabID: UUID) {
        // Validate tab exists before closing
        let tabExists = domain.tabs.contains { $0.id == tabID }
        guard tabExists else {
            Diagnostics.logError("Attempted to close tab \(tabID) that doesn't exist in current session", subsystem: LogSubsystem.runtime, category: "tab")
            return // recovery: do nothing if tab not found
        }
        domain.activeSessionStore.closeTab(id: tabID)
    }
    func selectTab(_ tabID: UUID) {
        // Validate tab exists before selecting
        let tabExists = domain.tabs.contains { $0.id == tabID }
        guard tabExists else {
            Diagnostics.logError("Attempted to select tab \(tabID) that doesn't exist in current session", subsystem: LogSubsystem.runtime, category: "tab")
            return // recovery: do nothing if tab not found
        }
        domain.activeSessionStore.selectTab(id: tabID)
    }
    // MARK: - URL Loading
    func loadURL(_ url: URL) {
        navigationDomain.loadURL(url, force: false)
    }
    func loadURLString(_ string: String, force: Bool = false) {
        navigationDomain.openURLString(string, force: force)
    }
    // MARK: - Session Lifecycle
    func persistSessionNow() {
        domain.activeSessionStore.saveNow()
    }
    func invalidateSession() {
        // Safely close all tabs (store keeps one default tab minimum)
        let tabsToClose = domain.tabs
        guard !tabsToClose.isEmpty else {
            // Already empty, nothing to close
            return
        }
        for tab in tabsToClose {
            // Double-check tab still exists (could be removed in store callback)
            if domain.tabs.contains(where: { $0.id == tab.id }) {
                domain.activeSessionStore.closeTab(id: tab.id)
            }
        }
    }
}

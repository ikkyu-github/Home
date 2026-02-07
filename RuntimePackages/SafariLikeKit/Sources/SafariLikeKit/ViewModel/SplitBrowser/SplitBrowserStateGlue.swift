import Foundation
import Combine
import SwiftUI
import UIKit
import WebKit
import SafariLikeContracts
import SafariLikeCoreKit
@MainActor
final class SplitBrowserStateGlue: ObservableObject {
    // MARK: - Root
    private weak var root: SplitBrowserViewModel?
    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()
    private var sessionCancellables = Set<AnyCancellable>()
    private var modeCancellables = Set<AnyCancellable>()
    private var addressBarCancellables = Set<AnyCancellable>()
    // MARK: - Init
    init(root: SplitBrowserViewModel) {
        self.root = root
        attachCoreMirrors()
    }
    // MARK: - Public bind entry
    /// Bind session selection (called on init + when switching private mode)
    func bindSessionSelection(for store: BrowserSessionStore) {
        guard let rootVM = self.root else { return }
        sessionCancellables.removeAll()
        rootVM.tabManager.bindSessionSelection(for: store)
    }
    /// One-time bindings that mirror internal controller state to ViewModel
    func bind() {
        bindModeChanges()
    }
    // MARK: - Core mirrors
    private func attachCoreMirrors() {
        guard let rootVM = self.root else { return }
        // Suggestions mirror
        rootVM.addressBar.$suggestions
            .receive(on: RunLoop.main)
            .sink { [weak rootVM] new in
                rootVM?.suggestions = new
            }
            .store(in: &addressBarCancellables)
    }
    // MARK: - Mode / companion rules
    private func bindModeChanges() {
        guard let rootVM = self.root else { return }
        rootVM.$state
            .map { (state: SplitBrowserViewModel.State) in state.isAutoCompanionEnabled }
            .removeDuplicates()
            .sink { [weak rootVM] (enabled: Bool) in
                guard let rootVM else { return }
                if enabled {
                    rootVM.destroyRightPaneForRoot()
                }
            }
            .store(in: &modeCancellables)
    }
    // MARK: - Sidebar handling (ของจริงตาม SidebarView.Item ในโปรเจ็กต์คุณ)
    func handleSidebarSelect(_ item: SidebarView.Item) {
        guard let rootVM = self.root else { return }
        switch item {
        case .startPage:
            rootVM.setSidebarVisible(false)
            rootVM.showSidebar(content: .menu)
            if let id = rootVM.activeTabID {
                rootVM.updateTab(id: id, urlString: "about:blank")
            }
            Task { @MainActor in
                await rootVM.windowCoordinator.openURLString("about:blank", force: true)
            }
        case .privateMode:
            rootVM.togglePrivateMode()
            Task { @MainActor in
                await rootVM.windowCoordinator.openURLString("about:blank", force: true)
            }
        case .newTab:
            rootVM.newTab()
        case .tabOverview:
            rootVM.setSidebarVisible(false)
            rootVM.showSidebar(content: .menu)
            rootVM.presentTabOverview()
        case .bookmarks:
            rootVM.showSidebar(content: .bookmarks)
        case .readingList:
            rootVM.showSidebar(content: .readingList)
        case .history:
            rootVM.showSidebar(content: .history)
        case .settings:
            // ปิด sidebar ถ้าเป็น overlay/กำลังเปิดอยู่ เพื่อ UX ที่นิ่ง
            rootVM.windowCoordinator.setSidebarMode(.hidden)
            // เปิด app settings sheet
            rootVM.chrome.isAppSettingsPresented = true
        }
    }
    // MARK: - Sidebar / overview glue
    func toggleSidebar() {
        guard let rootVM = self.root else { return }
        rootVM.toggleSidebar()
    }
    func showSidebar(content: SplitBrowserViewModel.SidebarContent) {
        guard let rootVM = self.root else { return }
        rootVM.showSidebar(content: content)
    }
    func presentTabOverview() {
        guard let rootVM = self.root else { return }
        rootVM.presentTabOverview()
    }
    func dismissTabOverview() {
        guard let rootVM = self.root else { return }
        rootVM.dismissTabOverview()
    }
    // MARK: - Scroll / chrome reactions
    func handleWebScroll(contentOffset: CGPoint, scrollView: UIScrollView) {
        guard let rootVM = self.root else { return }
        // Preserve existing behavior: collapse bottom bar on scroll
        if contentOffset.y > 8 {
            rootVM.isBottomBarCollapsed = true
        } else if contentOffset.y <= 0 {
            rootVM.isBottomBarCollapsed = false
        }
        // Let chrome observe scroll physics too (if you want Safari-like collapsible bars)
        rootVM.applyWebsitePreferencesForActiveHost()
        let velocityY = scrollView.panGestureRecognizer.velocity(in: scrollView).y
        rootVM.activeStore?.requestRelatedSuggestionsFromScrollIfNeeded(
            contentOffsetY: contentOffset.y,
            panVelocityY: velocityY
        )
    }
    // MARK: - Website preferences helpers (ของจริง: WebsitePreferencesStore + TabWebStore)
    private func activeHost() -> String? {
        guard let rootVM = self.root else { return nil }
        guard let s = rootVM.activeURLString, let url = URL(string: s) else { return nil }
        return url.host
    }
    /// Helper to update preferences for the active host using the
    /// injected WebsitePreferencesProviding dependency on the root VM.
    private func updatePreferencesForActiveHost(_ mutate: (inout WebsitePreferences) -> Void) {
        guard let rootVM = self.root, let host = activeHost() else { return }
        var prefs = rootVM.websitePreferencesStore.getPreferences(for: host)
        mutate(&prefs)
        prefs.markModified()
        rootVM.websitePreferencesStore.setPreferences(prefs, for: host)
    }
    // MARK: - Website preferences / actions
    func applyWebsitePreferencesForActiveHost() {
        guard let rootVM = self.root else { return }
        if rootVM.activeStore == nil, rootVM.activeTabID != nil {
            // Attempt recovery if activeStore is missing
            rootVM.recoverIfActiveStoreMissing()
            // Try again after rebinding (next run loop)
            Task { @MainActor [weak self] in
                await Task.yield()
                self?.applyWebsitePreferencesForActiveHost()
            }
            return
        }
        guard
            let store = rootVM.activeStore,
            let url = store.state.currentURL,
            let host = url.host
        else {
            return
        }
        // If the preferences store also supports applying to WKWebViewConfiguration,
        // use the protocol-based hook from SafariLikeCoreKit to update the active webView.
        if let applier = rootVM.websitePreferencesStore as? WebsitePreferencesApplying {
            if let webView = store.webViewHandle?.webView {
                applier.applyPreferences(to: webView.configuration, forHost: host)
            }
        }
        // Also apply zoom preference if available on the WebView.
        let prefs = rootVM.websitePreferencesStore.getPreferences(for: host)
        #if os(iOS)
        if #available(iOS 15.0, *) {
            if let webView = store.webViewHandle?.webView {
                webView.pageZoom = prefs.zoom
            }
        }
        #endif
    }
    func applyReaderPreferencesForActiveHost() {
        guard let rootVM = self.root else { return }
        guard
            let store = rootVM.activeStore,
            let webView = store.webViewHandle?.webView,
            let url = store.state.currentURL,
            let host = url.host
        else {
            return
        }
        let prefs = rootVM.websitePreferencesStore.getPreferences(for: host)
        // Only update style if reader is enabled for this tab.
        if let tabID = rootVM.activeTabID,
           let tab = rootVM.tabManager.state.tabs.first(where: { $0.id == tabID }),
           tab.reader.isReaderEnabled {
            Task { @MainActor in
                await LightweightReaderModeController.updateStyleIfEnabled(in: webView, preferences: prefs)
            }
        }
    }
    func toggleReaderModeForActiveTab() {
        guard let rootVM = self.root else { return }
        guard
            let tabID = rootVM.activeTabID,
            let store = rootVM.activeStore,
            let webView = store.webViewHandle?.webView,
            let url = store.state.currentURL,
            let host = url.host
        else {
            return
        }
        let current = rootVM.tabManager.state.tabs.first(where: { $0.id == tabID })?.reader
        let isEnabled = current?.isReaderEnabled ?? false
        Task { @MainActor in
            if isEnabled {
                await LightweightReaderModeController.disable(in: webView)
                rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: false)
                return
            }
            let available = await LightweightReaderModeController.isReaderAvailable(in: webView)
            rootVM.tabManager.setReaderAvailability(tabID: tabID, isAvailable: available)
            guard available else { return }
            let prefs = rootVM.websitePreferencesStore.getPreferences(for: host)
            do {
                try await LightweightReaderModeController.enable(in: webView, preferences: prefs)
                rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: true)
            } catch {
                rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: false)
            }
        }
    }
    func refreshReaderStateAfterPageDidFinish(tabID: UUID, store: SafariLikeCoreKit.TabWebStore, url: URL?) {
        guard let rootVM = self.root else { return }
        guard let webView = store.webViewHandle?.webView else { return }
        guard let host = url?.host else {
            rootVM.tabManager.setReaderAvailability(tabID: tabID, isAvailable: false)
            return
        }
        let prefs = rootVM.websitePreferencesStore.getPreferences(for: host)
        Task { @MainActor in
            let available = await LightweightReaderModeController.isReaderAvailable(in: webView)
            rootVM.tabManager.setReaderAvailability(tabID: tabID, isAvailable: available)
            let tab = rootVM.tabManager.state.tabs.first(where: { $0.id == tabID })
            let shouldEnable = (tab?.reader.isReaderEnabled ?? false) || prefs.readerDefault
            guard available else {
                await LightweightReaderModeController.disable(in: webView)
                rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: false)
                return
            }
            if shouldEnable {
                do {
                    try await LightweightReaderModeController.enable(in: webView, preferences: prefs)
                    rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: true)
                } catch {
                    rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: false)
                }
            } else {
                // Ensure we're not leaving an overlay around from a previous navigation.
                await LightweightReaderModeController.disable(in: webView)
                rootVM.tabManager.setReaderEnabled(tabID: tabID, isEnabled: false)
            }
        }
    }
    func zoomIn() {
        updatePreferencesForActiveHost { prefs in
            let step: Double = 0.1
            let minZoom: Double = 0.5
            let maxZoom: Double = 2.0
            let current = prefs.zoom
            let next = min(maxZoom, current + step)
            prefs.zoom = max(minZoom, next)
        }
    }
    func zoomOut() {
        updatePreferencesForActiveHost { prefs in
            let step: Double = 0.1
            let minZoom: Double = 0.5
            let maxZoom: Double = 2.0
            let current = prefs.zoom
            let next = max(minZoom, current - step)
            prefs.zoom = min(maxZoom, next)
        }
    }
    func resetZoom() {
        updatePreferencesForActiveHost { prefs in
            prefs.zoom = 1.0
        }
    }
    func toggleDesktopMode() {
        updatePreferencesForActiveHost { prefs in
            prefs.prefersDesktop.toggle()
        }
    }
    func toggleReaderDefault() {
        updatePreferencesForActiveHost { prefs in
            prefs.readerDefault.toggle()
        }
    }
    func resetWebsiteSettings() {
        guard let rootVM = self.root else { return }
        guard let host = activeHost() else { return }
        let defaults = WebsitePreferences.defaults(for: host)
        rootVM.websitePreferencesStore.setPreferences(defaults, for: host)
        rootVM.reload()
    }
    func shareCurrentPage() {
                guard let rootVM = root else { return }
                rootVM.shareCoordinator.shareCurrentPageLink(from: rootVM)
    }
    func addBookmarkForActivePage() {
        guard let rootVM = self.root, let store = rootVM.activeStore, let url = store.state.currentURL?.absoluteString else { return }
        let title = store.state.pageTitle
        rootVM.bookmarkStore.addOrUpdate(title: title, urlString: url)
    }
    func addToReadingListForActivePage() {
        guard let rootVM = self.root, let store = rootVM.activeStore, let url = store.state.currentURL?.absoluteString else { return }
        let title = store.state.pageTitle
        rootVM.readingListStore.addOrUpdate(title: title, urlString: url)
    }
}

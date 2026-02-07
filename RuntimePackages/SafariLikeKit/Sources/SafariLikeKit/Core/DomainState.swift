import Foundation
import Combine
import SafariLikeCoreKit
/// Internal implementation of BrowserDomainState.
/// Owns tabs, registries, and session management.
@MainActor
final class BrowserDomainStateImpl: BrowserDomainState {
    // MARK: - Session Stores
    private let normalSessionStore: BrowserSessionStore
    private let privateSessionStore: BrowserSessionStore
    var isPrivateMode: Bool = false
    var activeSessionStore: BrowserSessionStore {
        isPrivateMode ? privateSessionStore : normalSessionStore
    }
    // MARK: - Tab Management
    private let tabManager: TabManager
    var activeTabID: UUID? {
        get { activeSessionStore.selectedTabID }
        set {
            if let newValue = newValue {
                tabManager.selectTab(newValue)
            }
        }
    }
    var tabs: [BrowserTab] {
        activeSessionStore.tabs
    }
    var activeStore: (any WebStoreProviding)? {
        tabManager.activeStore
    }
    // MARK: - Libraries
    let bookmarkStore: BookmarkStore
    let historyStore: HistoryStore
    let readingListStore: ReadingListStore
    let downloadStore: any DownloadProviding
    // MARK: - Navigation State (from activeStore)
    var canGoBack: Bool {
        activeSessionStore.canGoBack(tabID: activeTabID)
    }
    var canGoForward: Bool {
        activeSessionStore.canGoForward(tabID: activeTabID)
    }
    var isLoading: Bool {
        activeStore?.state.isLoading ?? false
    }
    // MARK: - Init
    init(
        normalSessionStore: BrowserSessionStore,
        privateSessionStore: BrowserSessionStore,
        tabManager: TabManager,
        bookmarkStore: BookmarkStore,
        historyStore: HistoryStore,
        readingListStore: ReadingListStore,
        downloadStore: any DownloadProviding
    ) {
        self.normalSessionStore = normalSessionStore
        self.privateSessionStore = privateSessionStore
        self.tabManager = tabManager
        self.bookmarkStore = bookmarkStore
        self.historyStore = historyStore
        self.readingListStore = readingListStore
        self.downloadStore = downloadStore
    }
}

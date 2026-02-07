import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
/// Window-scoped session surface backing PluginContext APIs.
///
/// This is intentionally UI/WebKit-free. NavigationService and TabManager
@MainActor
final class WindowPluginSessionProvider: PluginSessionProvider, TabQueryService, HistoryQueryService, BookmarksQueryService, @unchecked Sendable {
    private weak var tabManager: TabManager?
    // These are safe, nonisolated snapshots (window-scoped and effectively stable).
    nonisolated private let isPrivateModeSnapshot: Bool
    nonisolated private let isContentBlockingEnabledSnapshot: Bool
    nonisolated private let userAgentModeSnapshot: BrowserSettingsSnapshot.UserAgentMode
    nonisolated private let searchEngineURLTemplateSnapshot: String
    private let tabQueryService: TabQueryService
    private let historyQueryService: HistoryQueryService
    private let bookmarksQueryService: BookmarksQueryService
    private var lastNavigationRequest: NavigationRequest?
    private var nextToken: UUID {
        UUID()
    }
    private var navigationSubscribers: [UUID: @MainActor (NavigationEvent) -> Void] = [:]
    private var navigationInterceptors: [UUID: @MainActor (NavigationRequest) async -> InterceptionResponse] = [:]
    init(
        tabManager: TabManager,
        historyStore: HistoryStore,
        bookmarkStore: BookmarkStore
    ) {
        self.tabManager = tabManager
        self.isPrivateModeSnapshot = tabManager.isPrivateMode
        self.isContentBlockingEnabledSnapshot = true
        self.userAgentModeSnapshot = .mobile
        self.searchEngineURLTemplateSnapshot = "https://www.google.com/search?q=%@"
        self.tabQueryService = CoreTabQueryService(tabManager: tabManager)
        self.historyQueryService = CoreHistoryQueryService(historyStore: historyStore)
        self.bookmarksQueryService = CoreBookmarksQueryService(bookmarkStore: bookmarkStore)
    }
    // MARK: - Publishing (called by runtime)
    func updateCurrentNavigationRequest(_ request: NavigationRequest?) {
        lastNavigationRequest = request
    }
    func publish(_ event: NavigationEvent) {
        for handler in navigationSubscribers.values {
            handler(event)
        }
    }
    func evaluateInterceptors(_ request: NavigationRequest) async -> InterceptionResponse {
        // Deterministic order for stability.
        let ordered = navigationInterceptors.keys.sorted { $0.uuidString < $1.uuidString }
        for key in ordered {
            guard let handler = navigationInterceptors[key] else { continue }
            let response = await handler(request)
            switch response {
            case .allow:
                continue
            default:
                return response
            }
        }
        return .allow
    }
    // MARK: - PluginSessionProvider
    nonisolated func getCurrentTabURL() async -> String? {
        await MainActor.run { [weak self] in
            self?.tabManager?.activeStore?.state.currentURL?.absoluteString
        }
    }
    nonisolated func getCurrentNavigationRequest() async -> NavigationRequest? {
        await MainActor.run { [weak self] in
            self?.lastNavigationRequest
        }
    }
    nonisolated func subscribeToNavigationEvents(
        handler: @escaping @MainActor (NavigationEvent) -> Void
    ) async -> PluginEventSubscription {
        await MainActor.run { [weak self] in
            guard let self else {
                return PluginEventSubscription { @MainActor in }
            }
            let key = self.nextToken
            self.navigationSubscribers[key] = handler
            return PluginEventSubscription { @MainActor [weak self] in
                self?.navigationSubscribers.removeValue(forKey: key)
            }
        }
    }
    nonisolated func registerNavigationInterceptor(
        handler: @escaping @MainActor (NavigationRequest) async -> InterceptionResponse
    ) async -> PluginEventSubscription {
        await MainActor.run { [weak self] in
            guard let self else {
                return PluginEventSubscription { @MainActor in }
            }
            let key = self.nextToken
            self.navigationInterceptors[key] = handler
            return PluginEventSubscription { @MainActor [weak self] in
                self?.navigationInterceptors.removeValue(forKey: key)
            }
        }
    }
    nonisolated func injectScript(scriptID: String, source: String, timing: InjectionTiming) async throws {
        // Runtime injection into an already-created WebView is not supported yet.
        throw PluginError.invalidConfiguration("injectScript is not supported at runtime")
    }
    nonisolated func removeScript(scriptID: String) async throws {
        throw PluginError.invalidConfiguration("removeScript is not supported at runtime")
    }
    nonisolated func getIsPrivateMode() -> Bool {
        isPrivateModeSnapshot
    }
    nonisolated func getIsContentBlockingEnabled() -> Bool {
        isContentBlockingEnabledSnapshot
    }
    nonisolated func getUserAgentMode() -> BrowserSettingsSnapshot.UserAgentMode {
        userAgentModeSnapshot
    }
    nonisolated func getSearchEngineURLTemplate() -> String {
        searchEngineURLTemplateSnapshot
    }
    // MARK: - TabQueryService
    nonisolated func openTabs() async throws -> [PluginTabSnapshot] {
        let service = await MainActor.run { [weak self] in self?.tabQueryService }
        guard let service else { throw PluginError.sessionUnloaded }
        return try await service.openTabs()
    }
    // MARK: - HistoryQueryService
    nonisolated func recentHistory(limit: Int) async throws -> [PluginHistoryItem] {
        let service = await MainActor.run { [weak self] in self?.historyQueryService }
        guard let service else { throw PluginError.sessionUnloaded }
        return try await service.recentHistory(limit: limit)
    }
    // MARK: - BookmarksQueryService
    nonisolated func bookmarks() async throws -> [PluginBookmarkItem] {
        let service = await MainActor.run { [weak self] in self?.bookmarksQueryService }
        guard let service else { throw PluginError.sessionUnloaded }
        return try await service.bookmarks()
    }
}

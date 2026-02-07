import Foundation
import CryptoKit
import SafariLikeContracts
import SafariLikeCoreKit
/// Core-backed implementations of plugin QueryService protocols.
///
/// These types are intentionally read-only adapters. They translate Core-owned
/// state into plugin-safe snapshot models without embedding plugin/business logic.
// MARK: - Core → Plugin Mapping
/// Centralized mapping from Core-owned models to plugin-safe snapshots.
///
/// Rule: plugins consume snapshots; Core retains ownership.
private enum CoreToPluginSnapshotMapper {
    static func tabSnapshot(from tab: BrowserTab, isActive: Bool, idSalt: UUID) -> PluginTabSnapshot {
        PluginTabSnapshot(
            id: opaqueTabID(for: tab.id, salt: idSalt),
            title: nilIfEmpty(tab.title),
            urlString: normalizedURLString(tab.urlString),
            isActive: isActive
        )
    }
    static func historyItem(from item: BrowserHistoryItem) -> PluginHistoryItem {
        PluginHistoryItem(
            urlString: item.urlString,
            title: nilIfEmpty(item.title),
            lastVisitedAt: item.visitedAt
        )
    }
    static func bookmarkItem(from item: BrowserBookmark) -> PluginBookmarkItem {
        PluginBookmarkItem(
            urlString: item.urlString,
            title: nilIfEmpty(item.title)
        )
    }
    // MARK: Helpers
    /// Produces an opaque, per-window-stable ID without leaking Core UUIDs.
    private static func opaqueTabID(for coreID: UUID, salt: UUID) -> String {
        let data = Data("\(coreID.uuidString)|\(salt.uuidString)".utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    private static func nilIfEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private static func normalizedURLString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
final class CoreTabQueryService: TabQueryService, @unchecked Sendable {
    private weak var tabManager: TabManager?
    private let tabIDSalt: UUID
    init(tabManager: TabManager, tabIDSalt: UUID = UUID()) {
        self.tabManager = tabManager
        self.tabIDSalt = tabIDSalt
    }
    func openTabs() async throws -> [PluginTabSnapshot] {
        try await MainActor.run {
            guard let tabManager else {
                throw PluginError.sessionUnloaded
            }
            return tabManager.withCurrentSessionStore { store in
                let selected = store.selectedTabID
                return store.tabs.map { tab in
                    CoreToPluginSnapshotMapper.tabSnapshot(
                        from: tab,
                        isActive: tab.id == selected,
                        idSalt: tabIDSalt
                    )
                }
            }
        }
    }
}
final class CoreSessionStoreTabQueryService: TabQueryService, @unchecked Sendable {
    private weak var sessionStore: BrowserSessionStore?
    private let tabIDSalt: UUID
    init(sessionStore: BrowserSessionStore, tabIDSalt: UUID = UUID()) {
        self.sessionStore = sessionStore
        self.tabIDSalt = tabIDSalt
    }
    func openTabs() async throws -> [PluginTabSnapshot] {
        try await MainActor.run {
            guard let sessionStore else {
                throw PluginError.sessionUnloaded
            }
            let selected = sessionStore.selectedTabID
            return sessionStore.tabs.map { tab in
                CoreToPluginSnapshotMapper.tabSnapshot(
                    from: tab,
                    isActive: tab.id == selected,
                    idSalt: tabIDSalt
                )
            }
        }
    }
}
final class CoreHistoryQueryService: HistoryQueryService, @unchecked Sendable {
    private weak var historyStore: HistoryStore?
    init(historyStore: HistoryStore) {
        self.historyStore = historyStore
    }
    func recentHistory(limit: Int) async throws -> [PluginHistoryItem] {
        try await MainActor.run {
            guard let historyStore else {
                throw PluginError.sessionUnloaded
            }
            let capped = max(0, limit)
            return Array(historyStore.items.prefix(capped)).map(CoreToPluginSnapshotMapper.historyItem(from:))
        }
    }
}
final class CoreLibraryRepositoryHistoryQueryService: HistoryQueryService, @unchecked Sendable {
    private let repository: any LibraryRepository
    private let profile: BrowsingProfile
    init(repository: any LibraryRepository, profile: BrowsingProfile) {
        self.repository = repository
        self.profile = profile
    }
    func recentHistory(limit: Int) async throws -> [PluginHistoryItem] {
        let capped = max(0, limit)
        let items = try await repository.fetchHistory(profile: profile)
        return Array(items.prefix(capped)).map(CoreToPluginSnapshotMapper.historyItem(from:))
    }
}
final class CoreBookmarksQueryService: BookmarksQueryService, @unchecked Sendable {
    private weak var bookmarkStore: BookmarkStore?
    init(bookmarkStore: BookmarkStore) {
        self.bookmarkStore = bookmarkStore
    }
    func bookmarks() async throws -> [PluginBookmarkItem] {
        try await MainActor.run {
            guard let bookmarkStore else {
                throw PluginError.sessionUnloaded
            }
            return bookmarkStore.items.map(CoreToPluginSnapshotMapper.bookmarkItem(from:))
        }
    }
}
final class CoreLibraryRepositoryBookmarksQueryService: BookmarksQueryService, @unchecked Sendable {
    private let repository: any LibraryRepository
    private let profile: BrowsingProfile
    init(repository: any LibraryRepository, profile: BrowsingProfile) {
        self.repository = repository
        self.profile = profile
    }
    func bookmarks() async throws -> [PluginBookmarkItem] {
        let items = try await repository.fetchBookmarks(profile: profile)
        return items.map(CoreToPluginSnapshotMapper.bookmarkItem(from:))
    }
}

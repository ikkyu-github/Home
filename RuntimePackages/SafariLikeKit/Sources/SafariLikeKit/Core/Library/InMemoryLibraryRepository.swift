import Foundation
import SafariLikeCoreKit
public actor InMemoryLibraryRepository: LibraryRepository {
    private struct State {
        var bookmarks: [BrowsingProfile: [BrowserBookmark]] = [:]
        var history: [BrowsingProfile: [BrowserHistoryItem]] = [:]
        var readingList: [BrowsingProfile: [BrowserReadingListItem]] = [:]
    }
    private var state = State()
    public init(
        regularBookmarks: [BrowserBookmark] = [],
        regularHistory: [BrowserHistoryItem] = [],
        regularReadingList: [BrowserReadingListItem] = []
    ) {
        state.bookmarks[.regular] = regularBookmarks
        state.history[.regular] = regularHistory
        state.readingList[.regular] = regularReadingList
        state.bookmarks[.private] = []
        state.history[.private] = []
        state.readingList[.private] = []
    }
    public func fetchBookmarks(profile: BrowsingProfile) async throws -> [BrowserBookmark] {
        state.bookmarks[profile] ?? []
    }
    public func upsertBookmark(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var items = state.bookmarks[profile] ?? []
        if let idx = items.firstIndex(where: { $0.urlString == normalized }) {
            if let title, !title.isEmpty {
                items[idx].title = title
            } else if items[idx].title.isEmpty {
                items[idx].title = normalized
            }
            items[idx].updatedAt = Date()
        } else {
            let name = (title?.isEmpty == false) ? (title ?? normalized) : normalized
            let newItem = BrowserBookmark(title: name, urlString: normalized)
            items.insert(newItem, at: 0)
        }
        state.bookmarks[profile] = items
    }
    public func renameBookmark(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        var items = state.bookmarks[profile] ?? []
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[idx].title = trimmed
        items[idx].updatedAt = Date()
        state.bookmarks[profile] = items
    }
    public func removeBookmark(profile: BrowsingProfile, id: UUID) async throws {
        var items = state.bookmarks[profile] ?? []
        items.removeAll { $0.id == id }
        state.bookmarks[profile] = items
    }
    public func removeAllBookmarks(profile: BrowsingProfile) async throws {
        state.bookmarks[profile] = []
    }
    public func fetchHistory(profile: BrowsingProfile) async throws -> [BrowserHistoryItem] {
        state.history[profile] ?? []
    }
    public func recordHistoryVisit(profile: BrowsingProfile, urlString: String, title: String, at date: Date) async throws {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var items = state.history[profile] ?? []
        let t = title.isEmpty ? normalized : title
        let newItem = BrowserHistoryItem(title: t, urlString: normalized, visitedAt: date)
        items.insert(newItem, at: 0)
        state.history[profile] = items
    }
    public func updateMostRecentHistoryTitleIfNeeded(profile: BrowsingProfile, urlString: String, title: String) async throws {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !title.isEmpty else { return }
        var items = state.history[profile] ?? []
        guard let first = items.first, first.urlString == normalized else { return }
        if first.title != title {
            var updated = first
            updated.title = title
            items[0] = updated
            state.history[profile] = items
        }
    }
    public func removeHistoryItem(profile: BrowsingProfile, id: UUID) async throws {
        var items = state.history[profile] ?? []
        items.removeAll { $0.id == id }
        state.history[profile] = items
    }
    public func removeAllHistory(profile: BrowsingProfile) async throws {
        state.history[profile] = []
    }
    public func fetchReadingList(profile: BrowsingProfile) async throws -> [BrowserReadingListItem] {
        state.readingList[profile] ?? []
    }
    public func upsertReadingListItem(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        var items = state.readingList[profile] ?? []
        if let idx = items.firstIndex(where: { $0.urlString == normalized }) {
            if let title, !title.isEmpty {
                items[idx].title = title
            } else if items[idx].title.isEmpty {
                items[idx].title = normalized
            }
        } else {
            let name = (title?.isEmpty == false) ? (title ?? normalized) : normalized
            let newItem = BrowserReadingListItem(title: name, urlString: normalized)
            items.insert(newItem, at: 0)
        }
        state.readingList[profile] = items
    }
    public func markReadingListRead(profile: BrowsingProfile, id: UUID, isRead: Bool) async throws {
        var items = state.readingList[profile] ?? []
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].isRead = isRead
        state.readingList[profile] = items
    }
    public func markReadingListOpened(profile: BrowsingProfile, id: UUID, at date: Date) async throws {
        var items = state.readingList[profile] ?? []
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].lastOpenedAt = date
        items[idx].isRead = true
        state.readingList[profile] = items
    }
    public func renameReadingListItem(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        var items = state.readingList[profile] ?? []
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[idx].title = trimmed
        state.readingList[profile] = items
    }
    public func removeReadingListItem(profile: BrowsingProfile, id: UUID) async throws {
        var items = state.readingList[profile] ?? []
        items.removeAll { $0.id == id }
        state.readingList[profile] = items
    }
    public func removeAllReadingList(profile: BrowsingProfile) async throws {
        state.readingList[profile] = []
    }
}

import Foundation
import SafariLikeCoreKit
public protocol LibraryRepository: Sendable {
    func fetchBookmarks(profile: BrowsingProfile) async throws -> [BrowserBookmark]
    func upsertBookmark(profile: BrowsingProfile, title: String?, urlString: String) async throws
    func renameBookmark(profile: BrowsingProfile, id: UUID, newTitle: String) async throws
    func removeBookmark(profile: BrowsingProfile, id: UUID) async throws
    func removeAllBookmarks(profile: BrowsingProfile) async throws
    func fetchHistory(profile: BrowsingProfile) async throws -> [BrowserHistoryItem]
    func recordHistoryVisit(profile: BrowsingProfile, urlString: String, title: String, at date: Date) async throws
    func updateMostRecentHistoryTitleIfNeeded(profile: BrowsingProfile, urlString: String, title: String) async throws
    func removeHistoryItem(profile: BrowsingProfile, id: UUID) async throws
    func removeAllHistory(profile: BrowsingProfile) async throws
    func fetchReadingList(profile: BrowsingProfile) async throws -> [BrowserReadingListItem]
    func upsertReadingListItem(profile: BrowsingProfile, title: String?, urlString: String) async throws
    func markReadingListRead(profile: BrowsingProfile, id: UUID, isRead: Bool) async throws
    func markReadingListOpened(profile: BrowsingProfile, id: UUID, at date: Date) async throws
    func renameReadingListItem(profile: BrowsingProfile, id: UUID, newTitle: String) async throws
    func removeReadingListItem(profile: BrowsingProfile, id: UUID) async throws
    func removeAllReadingList(profile: BrowsingProfile) async throws
    /// Best-effort hook for repos that buffer writes.
    func flush() async
}
public extension LibraryRepository {
    func flush() async {}
}
public enum LibraryRepositoryError: Error {
    case invalidURLString
    case sqliteUnavailable
    case sqliteError(String)
}

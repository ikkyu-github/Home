import Foundation
import SafariLikeContracts

public enum LibraryRepositoryError: Error, Sendable {
    case sqliteUnavailable
    case sqliteError(String)
    case invalidArgument
}

public protocol LibraryRepository: Sendable {
    // History
    func recordHistoryVisit(profile: LibraryProfile, url: CanonicalURL, title: String, at date: Date) async throws
    func queryHistory(profile: LibraryProfile, query: String, limit: Int) async throws -> [HistoryEntry]
    func topSiteSignals(profile: LibraryProfile, since: Date, limit: Int) async throws -> [(url: CanonicalURL, title: String?, visitCount: Int, lastVisitedAt: Date)]
    func clearHistory(profile: LibraryProfile, since: Date?) async throws

    // Bookmarks
    func fetchBookmarkNodes(profile: LibraryProfile) async throws -> [BookmarkNode]
    func upsertBookmarkNode(profile: LibraryProfile, node: BookmarkNode) async throws
    func removeBookmarkNode(profile: LibraryProfile, id: UUID) async throws
    func setBookmarkFavorite(profile: LibraryProfile, id: UUID, isFavorite: Bool) async throws
    func queryBookmarks(profile: LibraryProfile, query: String, limit: Int) async throws -> [BookmarkNode]

    // Reading List
    func fetchReadingList(profile: LibraryProfile) async throws -> [ReadingListItem]
    func upsertReadingListItem(profile: LibraryProfile, item: ReadingListItem) async throws
    func removeReadingListItem(profile: LibraryProfile, id: UUID) async throws
    func queryReadingList(profile: LibraryProfile, query: String, limit: Int) async throws -> [ReadingListItem]

    // Top Sites overrides
    func fetchTopSiteOverrides(profile: LibraryProfile) async throws -> [TopSiteOverride]
    func upsertTopSiteOverride(profile: LibraryProfile, overrideValue: TopSiteOverride) async throws

    // Maintenance
    func counts(profile: LibraryProfile) async throws -> (historyVisits: Int, bookmarks: Int, readingList: Int, topSiteOverrides: Int)
}

public struct TopSiteOverride: Codable, Hashable, Sendable {
    public var url: CanonicalURL
    public var isPinned: Bool
    public var orderIndex: Int?
    public var isHidden: Bool
    public var title: String?

    public init(url: CanonicalURL, isPinned: Bool, orderIndex: Int? = nil, isHidden: Bool = false, title: String? = nil) {
        self.url = url
        self.isPinned = isPinned
        self.orderIndex = orderIndex
        self.isHidden = isHidden
        self.title = title
    }
}

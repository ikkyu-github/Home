import Foundation
import SafariLikeContracts

#if canImport(SQLite3)
import SQLite3

private func browserCoreSQLiteFreeDestructor(_ ptr: UnsafeMutableRawPointer?) {
    if let ptr { free(ptr) }
}
#endif

/// SQLite-backed repository for Safari-like Library data.
///
/// Storage rules:
/// - Regular profile persists.
/// - Private profile callers should be blocked at engine level (repository accepts profile but does not enforce).
public actor SQLiteLibraryRepository: LibraryRepository {

    public struct Configuration: Sendable {
        public var databaseURL: URL
        public init(databaseURL: URL) {
            self.databaseURL = databaseURL
        }
    }

    private let config: Configuration

    #if canImport(SQLite3)
    private var db: OpaquePointer?
    #endif

    private var didOpen = false

    public init(config: Configuration) {
        self.config = config
    }

    deinit {
        #if canImport(SQLite3)
        if let db { sqlite3_close(db) }
        #endif
    }

    // MARK: - Public

    public func recordHistoryVisit(profile: LibraryProfile, url: CanonicalURL, title: String, at date: Date) async throws {
        try ensureOpenAndMigratedIfNeeded()

        // Upsert by canonical URL.
        let existing = try selectHistoryByURL(profile: profile, urlString: url.normalized)
        if var existing {
            let newTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? existing.title : title
            existing.title = newTitle
            existing.visitCount += 1
            existing.lastVisitedAt = max(existing.lastVisitedAt, date)
            try exec(
                "UPDATE history_entries SET title = ?, visitCount = ?, lastVisitedAt = ? WHERE profile = ? AND urlString = ?",
                binds: [
                    .text(existing.title),
                    .int(existing.visitCount),
                    .double(existing.lastVisitedAt.timeIntervalSince1970),
                    .text(profile.rawValue),
                    .text(url.normalized)
                ]
            )
        } else {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? url.normalized : title
            try exec(
                "INSERT INTO history_entries (profile, urlString, title, visitCount, firstVisitedAt, lastVisitedAt, domainKey) VALUES (?, ?, ?, ?, ?, ?, ?)",
                binds: [
                    .text(profile.rawValue),
                    .text(url.normalized),
                    .text(t),
                    .int(1),
                    .double(date.timeIntervalSince1970),
                    .double(date.timeIntervalSince1970),
                    .text(url.domainKey)
                ]
            )
        }
    }

    public func queryHistory(profile: LibraryProfile, query: String, limit: Int) async throws -> [HistoryEntry] {
        try ensureOpenAndMigratedIfNeeded()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cappedLimit = max(1, min(200, limit))

        if q.isEmpty {
            return try selectRecentHistory(profile: profile, limit: cappedLimit)
        }

        // Simple LIKE match on title/urlString/host.
        let like = "%\(q.lowercased())%"
        return try selectHistoryByLike(profile: profile, like: like, limit: cappedLimit)
    }

    public func topSiteSignals(profile: LibraryProfile, since: Date, limit: Int) async throws -> [(url: CanonicalURL, title: String?, visitCount: Int, lastVisitedAt: Date)] {
        try ensureOpenAndMigratedIfNeeded()
        let cappedLimit = max(1, min(200, limit))

        var out: [(CanonicalURL, String?, Int, Date)] = []
        try query(
            "SELECT urlString, title, visitCount, lastVisitedAt FROM history_entries WHERE profile = ? AND lastVisitedAt >= ? ORDER BY lastVisitedAt DESC LIMIT ?",
            binds: [
                .text(profile.rawValue),
                .double(since.timeIntervalSince1970),
                .int(cappedLimit)
            ]
        ) { stmt in
            guard let urlStr = sqlite3_column_text(stmt, 0) else { return }
            let titleStr = sqlite3_column_text(stmt, 1)
            let visitCount = sqlite3_column_int(stmt, 2)
            let lastVisited = sqlite3_column_double(stmt, 3)

            let s = String(cString: urlStr)
            guard let cu = CanonicalURL(string: s) else { return }
            let t = titleStr.map { String(cString: $0) }
            out.append((cu, t, Int(visitCount), Date(timeIntervalSince1970: lastVisited)))
        }
        return out
    }

    public func clearHistory(profile: LibraryProfile, since: Date?) async throws {
        try ensureOpenAndMigratedIfNeeded()
        if let since {
            try exec(
                "DELETE FROM history_entries WHERE profile = ? AND lastVisitedAt >= ?",
                binds: [.text(profile.rawValue), .double(since.timeIntervalSince1970)]
            )
        } else {
            try exec("DELETE FROM history_entries WHERE profile = ?", binds: [.text(profile.rawValue)])
        }
    }

    public func fetchBookmarkNodes(profile: LibraryProfile) async throws -> [BookmarkNode] {
        try ensureOpenAndMigratedIfNeeded()
        return try selectBookmarkNodes(profile: profile)
    }

    public func upsertBookmarkNode(profile: LibraryProfile, node: BookmarkNode) async throws {
        try ensureOpenAndMigratedIfNeeded()

        // Enforce type/url relationship.
        if node.type == .bookmark, node.url == nil { throw LibraryRepositoryError.invalidArgument }
        if node.type == .folder, node.url != nil { throw LibraryRepositoryError.invalidArgument }

        try exec(
            "INSERT INTO bookmark_nodes (profile, id, type, title, urlString, parentID, orderIndex, isFavorite) VALUES (?, ?, ?, ?, ?, ?, ?, ?) " +
            "ON CONFLICT(profile, id) DO UPDATE SET type=excluded.type, title=excluded.title, urlString=excluded.urlString, parentID=excluded.parentID, orderIndex=excluded.orderIndex, isFavorite=excluded.isFavorite",
            binds: [
                .text(profile.rawValue),
                .text(node.id.uuidString),
                .text(node.type.rawValue),
                .text(node.title),
                node.url.map { .text($0.normalized) } ?? .null,
                node.parentID.map { .text($0.uuidString) } ?? .null,
                .int(node.orderIndex),
                .int(node.isFavorite ? 1 : 0)
            ]
        )
    }

    public func removeBookmarkNode(profile: LibraryProfile, id: UUID) async throws {
        try ensureOpenAndMigratedIfNeeded()
        // Basic delete (no cascade); callers should delete children explicitly.
        try exec("DELETE FROM bookmark_nodes WHERE profile = ? AND id = ?", binds: [.text(profile.rawValue), .text(id.uuidString)])
    }

    public func setBookmarkFavorite(profile: LibraryProfile, id: UUID, isFavorite: Bool) async throws {
        try ensureOpenAndMigratedIfNeeded()
        try exec(
            "UPDATE bookmark_nodes SET isFavorite = ? WHERE profile = ? AND id = ?",
            binds: [.int(isFavorite ? 1 : 0), .text(profile.rawValue), .text(id.uuidString)]
        )
    }

    public func queryBookmarks(profile: LibraryProfile, query: String, limit: Int) async throws -> [BookmarkNode] {
        try ensureOpenAndMigratedIfNeeded()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cappedLimit = max(1, min(200, limit))
        if q.isEmpty { return try selectBookmarkNodes(profile: profile).prefix(cappedLimit).map { $0 } }
        let like = "%\(q.lowercased())%"
        return try selectBookmarkNodesByLike(profile: profile, like: like, limit: cappedLimit)
    }

    public func fetchReadingList(profile: LibraryProfile) async throws -> [ReadingListItem] {
        try ensureOpenAndMigratedIfNeeded()
        return try selectReadingList(profile: profile)
    }

    public func upsertReadingListItem(profile: LibraryProfile, item: ReadingListItem) async throws {
        try ensureOpenAndMigratedIfNeeded()

        try exec(
            "INSERT INTO reading_list_items (profile, id, urlString, title, addedAt, isRead, lastOpenedAt, isOfflineAvailable) VALUES (?, ?, ?, ?, ?, ?, ?, ?) " +
            "ON CONFLICT(profile, id) DO UPDATE SET urlString=excluded.urlString, title=excluded.title, addedAt=excluded.addedAt, isRead=excluded.isRead, lastOpenedAt=excluded.lastOpenedAt, isOfflineAvailable=excluded.isOfflineAvailable",
            binds: [
                .text(profile.rawValue),
                .text(item.id.uuidString),
                .text(item.url.normalized),
                .text(item.title),
                .double(item.addedAt.timeIntervalSince1970),
                .int(item.isRead ? 1 : 0),
                item.lastOpenedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                .int(item.isOfflineAvailable ? 1 : 0)
            ]
        )
    }

    public func removeReadingListItem(profile: LibraryProfile, id: UUID) async throws {
        try ensureOpenAndMigratedIfNeeded()
        try exec("DELETE FROM reading_list_items WHERE profile = ? AND id = ?", binds: [.text(profile.rawValue), .text(id.uuidString)])
    }

    public func queryReadingList(profile: LibraryProfile, query: String, limit: Int) async throws -> [ReadingListItem] {
        try ensureOpenAndMigratedIfNeeded()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let cappedLimit = max(1, min(200, limit))
        if q.isEmpty { return try selectReadingList(profile: profile, limit: cappedLimit) }
        let like = "%\(q.lowercased())%"
        return try selectReadingListByLike(profile: profile, like: like, limit: cappedLimit)
    }

    public func fetchTopSiteOverrides(profile: LibraryProfile) async throws -> [TopSiteOverride] {
        try ensureOpenAndMigratedIfNeeded()
        return try selectTopSiteOverrides(profile: profile)
    }

    public func upsertTopSiteOverride(profile: LibraryProfile, overrideValue: TopSiteOverride) async throws {
        try ensureOpenAndMigratedIfNeeded()

        try exec(
            "INSERT INTO top_site_overrides (profile, urlString, isPinned, orderIndex, isHidden, title) VALUES (?, ?, ?, ?, ?, ?) " +
            "ON CONFLICT(profile, urlString) DO UPDATE SET isPinned=excluded.isPinned, orderIndex=excluded.orderIndex, isHidden=excluded.isHidden, title=excluded.title",
            binds: [
                .text(profile.rawValue),
                .text(overrideValue.url.normalized),
                .int(overrideValue.isPinned ? 1 : 0),
                overrideValue.orderIndex.map { .int($0) } ?? .null,
                .int(overrideValue.isHidden ? 1 : 0),
                overrideValue.title.map { .text($0) } ?? .null
            ]
        )
    }

    public func counts(profile: LibraryProfile) async throws -> (historyVisits: Int, bookmarks: Int, readingList: Int, topSiteOverrides: Int) {
        try ensureOpenAndMigratedIfNeeded()
        let h = try selectCount(table: "history_entries", profile: profile)
        let b = try selectCount(table: "bookmark_nodes", profile: profile)
        let r = try selectCount(table: "reading_list_items", profile: profile)
        let t = try selectCount(table: "top_site_overrides", profile: profile)
        return (h, b, r, t)
    }

    // MARK: - Open / Schema

    private func ensureOpenAndMigratedIfNeeded() throws {
        if didOpen { return }
        try openDBIfPossible()
        try createSchemaIfNeeded()
        didOpen = true
    }

    private func openDBIfPossible() throws {
        #if canImport(SQLite3)
        if db != nil { return }
        let dir = config.databaseURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(config.databaseURL.path, &db, flags, nil) != SQLITE_OK {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        try exec("PRAGMA foreign_keys=ON")
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }

    private func createSchemaIfNeeded() throws {
        try exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")

        // History (dedup by URL).
        try exec("""
        CREATE TABLE IF NOT EXISTS history_entries (
            profile TEXT NOT NULL,
            urlString TEXT NOT NULL,
            title TEXT NOT NULL,
            visitCount INTEGER NOT NULL,
            firstVisitedAt REAL NOT NULL,
            lastVisitedAt REAL NOT NULL,
            domainKey TEXT NOT NULL,
            PRIMARY KEY (profile, urlString)
        )
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_history_entries_profile_lastVisitedAt ON history_entries(profile, lastVisitedAt DESC)")
        try exec("CREATE INDEX IF NOT EXISTS idx_history_entries_profile_domainKey ON history_entries(profile, domainKey)")

        // Bookmarks tree.
        try exec("""
        CREATE TABLE IF NOT EXISTS bookmark_nodes (
            profile TEXT NOT NULL,
            id TEXT NOT NULL,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            urlString TEXT,
            parentID TEXT,
            orderIndex INTEGER NOT NULL,
            isFavorite INTEGER NOT NULL,
            PRIMARY KEY (profile, id)
        )
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_bookmark_nodes_profile_parent ON bookmark_nodes(profile, parentID, orderIndex)")
        try exec("CREATE INDEX IF NOT EXISTS idx_bookmark_nodes_profile_isFavorite ON bookmark_nodes(profile, isFavorite)")
        try exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmark_nodes_profile_url ON bookmark_nodes(profile, urlString)")

        // Reading List.
        try exec("""
        CREATE TABLE IF NOT EXISTS reading_list_items (
            profile TEXT NOT NULL,
            id TEXT NOT NULL,
            urlString TEXT NOT NULL,
            title TEXT NOT NULL,
            addedAt REAL NOT NULL,
            isRead INTEGER NOT NULL,
            lastOpenedAt REAL,
            isOfflineAvailable INTEGER NOT NULL,
            PRIMARY KEY (profile, id)
        )
        """)
        try exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_reading_list_profile_url ON reading_list_items(profile, urlString)")
        try exec("CREATE INDEX IF NOT EXISTS idx_reading_list_profile_addedAt ON reading_list_items(profile, addedAt DESC)")

        // Top Sites overrides: pinned, hidden, manual order.
        try exec("""
        CREATE TABLE IF NOT EXISTS top_site_overrides (
            profile TEXT NOT NULL,
            urlString TEXT NOT NULL,
            isPinned INTEGER NOT NULL,
            orderIndex INTEGER,
            isHidden INTEGER NOT NULL,
            title TEXT,
            PRIMARY KEY (profile, urlString)
        )
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_top_site_overrides_profile_order ON top_site_overrides(profile, orderIndex)")

        let version = try selectMetaInt(key: "schema_version")
        if version == nil {
            try exec("INSERT OR REPLACE INTO meta(key, value) VALUES('schema_version', '1')")
        }
    }

    // MARK: - Private Queries

    private func selectHistoryByURL(profile: LibraryProfile, urlString: String) throws -> HistoryEntry? {
        var found: HistoryEntry?
        try query(
            "SELECT title, visitCount, firstVisitedAt, lastVisitedAt, domainKey FROM history_entries WHERE profile = ? AND urlString = ? LIMIT 1",
            binds: [.text(profile.rawValue), .text(urlString)]
        ) { stmt in
            guard let titleStr = sqlite3_column_text(stmt, 0) else { return }
            let visitCount = sqlite3_column_int(stmt, 1)
            let first = sqlite3_column_double(stmt, 2)
            let last = sqlite3_column_double(stmt, 3)
            let title = String(cString: titleStr)
            guard let cu = CanonicalURL(string: urlString) else { return }
            found = HistoryEntry(
                url: cu,
                title: title,
                visitCount: Int(visitCount),
                lastVisitedAt: Date(timeIntervalSince1970: last),
                firstVisitedAt: Date(timeIntervalSince1970: first)
            )
        }
        return found
    }

    private func selectRecentHistory(profile: LibraryProfile, limit: Int) throws -> [HistoryEntry] {
        var result: [HistoryEntry] = []
        try query(
            "SELECT urlString, title, visitCount, firstVisitedAt, lastVisitedAt FROM history_entries WHERE profile = ? ORDER BY lastVisitedAt DESC LIMIT ?",
            binds: [.text(profile.rawValue), .int(limit)]
        ) { stmt in
            guard let urlStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1) else { return }
            let visitCount = sqlite3_column_int(stmt, 2)
            let first = sqlite3_column_double(stmt, 3)
            let last = sqlite3_column_double(stmt, 4)
            let urlString = String(cString: urlStr)
            guard let cu = CanonicalURL(string: urlString) else { return }
            result.append(
                HistoryEntry(
                    url: cu,
                    title: String(cString: titleStr),
                    visitCount: Int(visitCount),
                    lastVisitedAt: Date(timeIntervalSince1970: last),
                    firstVisitedAt: Date(timeIntervalSince1970: first)
                )
            )
        }
        return result
    }

    private func selectHistoryByLike(profile: LibraryProfile, like: String, limit: Int) throws -> [HistoryEntry] {
        var result: [HistoryEntry] = []
        try query(
            "SELECT urlString, title, visitCount, firstVisitedAt, lastVisitedAt FROM history_entries WHERE profile = ? AND (lower(title) LIKE ? OR lower(urlString) LIKE ? OR lower(domainKey) LIKE ?) ORDER BY lastVisitedAt DESC LIMIT ?",
            binds: [.text(profile.rawValue), .text(like), .text(like), .text(like), .int(limit)]
        ) { stmt in
            guard let urlStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1) else { return }
            let visitCount = sqlite3_column_int(stmt, 2)
            let first = sqlite3_column_double(stmt, 3)
            let last = sqlite3_column_double(stmt, 4)
            let urlString = String(cString: urlStr)
            guard let cu = CanonicalURL(string: urlString) else { return }
            result.append(
                HistoryEntry(
                    url: cu,
                    title: String(cString: titleStr),
                    visitCount: Int(visitCount),
                    lastVisitedAt: Date(timeIntervalSince1970: last),
                    firstVisitedAt: Date(timeIntervalSince1970: first)
                )
            )
        }
        return result
    }

    private func selectBookmarkNodes(profile: LibraryProfile) throws -> [BookmarkNode] {
        var result: [BookmarkNode] = []
        try query(
            "SELECT id, type, title, urlString, parentID, orderIndex, isFavorite FROM bookmark_nodes WHERE profile = ? ORDER BY parentID ASC, orderIndex ASC",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let typeStr = sqlite3_column_text(stmt, 1),
                  let titleStr = sqlite3_column_text(stmt, 2) else { return }

            let urlStr = sqlite3_column_text(stmt, 3)
            let parentStr = sqlite3_column_text(stmt, 4)
            let orderIndex = sqlite3_column_int(stmt, 5)
            let isFavorite = sqlite3_column_int(stmt, 6)

            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            let type = BookmarkNodeType(rawValue: String(cString: typeStr)) ?? .bookmark
            let title = String(cString: titleStr)
            let url = urlStr.flatMap { CanonicalURL(string: String(cString: $0)) }
            let parent = parentStr.flatMap { UUID(uuidString: String(cString: $0)) }

            result.append(
                BookmarkNode(
                    id: id,
                    type: type,
                    title: title,
                    url: url,
                    parentID: parent,
                    orderIndex: Int(orderIndex),
                    isFavorite: isFavorite != 0
                )
            )
        }
        return result
    }

    private func selectBookmarkNodesByLike(profile: LibraryProfile, like: String, limit: Int) throws -> [BookmarkNode] {
        var result: [BookmarkNode] = []
        try query(
            "SELECT id, type, title, urlString, parentID, orderIndex, isFavorite FROM bookmark_nodes WHERE profile = ? AND lower(title) LIKE ? ORDER BY isFavorite DESC, title ASC LIMIT ?",
            binds: [.text(profile.rawValue), .text(like), .int(limit)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let typeStr = sqlite3_column_text(stmt, 1),
                  let titleStr = sqlite3_column_text(stmt, 2) else { return }

            let urlStr = sqlite3_column_text(stmt, 3)
            let parentStr = sqlite3_column_text(stmt, 4)
            let orderIndex = sqlite3_column_int(stmt, 5)
            let isFavorite = sqlite3_column_int(stmt, 6)

            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            let type = BookmarkNodeType(rawValue: String(cString: typeStr)) ?? .bookmark
            let title = String(cString: titleStr)
            let url = urlStr.flatMap { CanonicalURL(string: String(cString: $0)) }
            let parent = parentStr.flatMap { UUID(uuidString: String(cString: $0)) }

            result.append(
                BookmarkNode(
                    id: id,
                    type: type,
                    title: title,
                    url: url,
                    parentID: parent,
                    orderIndex: Int(orderIndex),
                    isFavorite: isFavorite != 0
                )
            )
        }
        return result
    }

    private func selectReadingList(profile: LibraryProfile, limit: Int? = nil) throws -> [ReadingListItem] {
        var result: [ReadingListItem] = []
        let sql = "SELECT id, urlString, title, addedAt, isRead, lastOpenedAt, isOfflineAvailable FROM reading_list_items WHERE profile = ? ORDER BY addedAt DESC" + (limit != nil ? " LIMIT ?" : "")
        var binds: [Bind] = [.text(profile.rawValue)]
        if let limit { binds.append(.int(limit)) }

        try query(sql, binds: binds) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let urlStr = sqlite3_column_text(stmt, 1),
                  let titleStr = sqlite3_column_text(stmt, 2) else { return }

            let addedAt = sqlite3_column_double(stmt, 3)
            let isRead = sqlite3_column_int(stmt, 4)
            let lastOpened = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
            let isOffline = sqlite3_column_int(stmt, 6)

            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            guard let url = CanonicalURL(string: String(cString: urlStr)) else { return }
            let title = String(cString: titleStr)

            result.append(
                ReadingListItem(
                    id: id,
                    url: url,
                    title: title,
                    addedAt: Date(timeIntervalSince1970: addedAt),
                    isRead: isRead != 0,
                    lastOpenedAt: lastOpened.map { Date(timeIntervalSince1970: $0) },
                    isOfflineAvailable: isOffline != 0
                )
            )
        }
        return result
    }

    private func selectReadingListByLike(profile: LibraryProfile, like: String, limit: Int) throws -> [ReadingListItem] {
        var result: [ReadingListItem] = []
        try query(
            "SELECT id, urlString, title, addedAt, isRead, lastOpenedAt, isOfflineAvailable FROM reading_list_items WHERE profile = ? AND lower(title) LIKE ? ORDER BY addedAt DESC LIMIT ?",
            binds: [.text(profile.rawValue), .text(like), .int(limit)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let urlStr = sqlite3_column_text(stmt, 1),
                  let titleStr = sqlite3_column_text(stmt, 2) else { return }

            let addedAt = sqlite3_column_double(stmt, 3)
            let isRead = sqlite3_column_int(stmt, 4)
            let lastOpened = sqlite3_column_type(stmt, 5) == SQLITE_NULL ? nil : sqlite3_column_double(stmt, 5)
            let isOffline = sqlite3_column_int(stmt, 6)

            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            guard let url = CanonicalURL(string: String(cString: urlStr)) else { return }
            let title = String(cString: titleStr)

            result.append(
                ReadingListItem(
                    id: id,
                    url: url,
                    title: title,
                    addedAt: Date(timeIntervalSince1970: addedAt),
                    isRead: isRead != 0,
                    lastOpenedAt: lastOpened.map { Date(timeIntervalSince1970: $0) },
                    isOfflineAvailable: isOffline != 0
                )
            )
        }
        return result
    }

    private func selectTopSiteOverrides(profile: LibraryProfile) throws -> [TopSiteOverride] {
        var result: [TopSiteOverride] = []
        try query(
            "SELECT urlString, isPinned, orderIndex, isHidden, title FROM top_site_overrides WHERE profile = ?",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let urlStr = sqlite3_column_text(stmt, 0) else { return }
            let isPinned = sqlite3_column_int(stmt, 1)
            let orderIndex = sqlite3_column_type(stmt, 2) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 2))
            let isHidden = sqlite3_column_int(stmt, 3)
            let title = sqlite3_column_type(stmt, 4) == SQLITE_NULL ? nil : sqlite3_column_text(stmt, 4).map { String(cString: $0) }

            let urlString = String(cString: urlStr)
            guard let url = CanonicalURL(string: urlString) else { return }

            result.append(
                TopSiteOverride(
                    url: url,
                    isPinned: isPinned != 0,
                    orderIndex: orderIndex,
                    isHidden: isHidden != 0,
                    title: title
                )
            )
        }
        return result
    }

    private func selectCount(table: String, profile: LibraryProfile) throws -> Int {
        var count: Int = 0
        try query(
            "SELECT COUNT(*) FROM \(table) WHERE profile = ?",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            count = Int(sqlite3_column_int(stmt, 0))
        }
        return count
    }

    private func selectMetaInt(key: String) throws -> Int? {
        var out: Int?
        try query("SELECT value FROM meta WHERE key = ? LIMIT 1", binds: [.text(key)]) { stmt in
            guard let valueStr = sqlite3_column_text(stmt, 0) else { return }
            out = Int(String(cString: valueStr))
        }
        return out
    }

    // MARK: - SQLite helpers

    private enum Bind {
        case text(String)
        case int(Int)
        case double(Double)
        case null
    }

    private func exec(_ sql: String, binds: [Bind] = []) throws {
        #if canImport(SQLite3)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        try bindAll(stmt: stmt, binds: binds)
        // Some statements (notably PRAGMAs) return one or more SQLITE_ROW results.
        // Drain rows until SQLITE_DONE.
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            if rc == SQLITE_ROW { continue }
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }

    private func query(_ sql: String, binds: [Bind] = [], row: (OpaquePointer?) -> Void) throws {
        #if canImport(SQLite3)
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        defer { sqlite3_finalize(stmt) }
        try bindAll(stmt: stmt, binds: binds)
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_ROW {
                row(stmt)
                continue
            }
            if rc == SQLITE_DONE { break }
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }

    private func bindAll(stmt: OpaquePointer?, binds: [Bind]) throws {
        #if canImport(SQLite3)
        for (index, b) in binds.enumerated() {
            let i = Int32(index + 1)
            switch b {
            case .text(let s):
                guard let cStr = strdup(s) else {
                    throw LibraryRepositoryError.sqliteError("strdup failed")
                }
                let rc = sqlite3_bind_text(stmt, i, cStr, -1, browserCoreSQLiteFreeDestructor)
                if rc != SQLITE_OK {
                    free(cStr)
                    throw LibraryRepositoryError.sqliteError(lastErrorMessage())
                }
            case .int(let n):
                sqlite3_bind_int(stmt, i, Int32(n))
            case .double(let d):
                sqlite3_bind_double(stmt, i, d)
            case .null:
                sqlite3_bind_null(stmt, i)
            }
        }
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }

    private func lastErrorMessage() -> String {
        #if canImport(SQLite3)
        if let db, let cStr = sqlite3_errmsg(db) {
            return String(cString: cStr)
        }
        #endif
        return "SQLite error"
    }
}

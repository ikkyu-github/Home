import Foundation
import SafariLikeCoreKit
#if canImport(SQLite3)
import SQLite3
#endif
public actor SQLiteLibraryRepository: LibraryRepository {
    public struct Configuration: Sendable {
        public var databaseURL: URL
        public var legacyBookmarksFilename: String?
        public var legacyHistoryFilename: String?
        public var legacyReadingListFilename: String?
        public init(
            databaseURL: URL,
            legacyBookmarksFilename: String? = nil,
            legacyHistoryFilename: String? = nil,
            legacyReadingListFilename: String? = nil
        ) {
            self.databaseURL = databaseURL
            self.legacyBookmarksFilename = legacyBookmarksFilename
            self.legacyHistoryFilename = legacyHistoryFilename
            self.legacyReadingListFilename = legacyReadingListFilename
        }
    }
    private let config: Configuration
    #if canImport(SQLite3)
    private var db: OpaquePointer?
    private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
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
    public func fetchBookmarks(profile: BrowsingProfile) async throws -> [BrowserBookmark] {
        try await ensureOpenAndMigratedIfNeeded()
        return try selectBookmarks(profile: profile)
    }
    public func upsertBookmark(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let now = Date()
        let finalTitle: String = {
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
            return normalized
        }()
        // Upsert by urlString.
        let existing = try selectBookmarkIDByURL(profile: profile, urlString: normalized)
        if let existing {
            try exec(
                "UPDATE bookmarks SET title = ?, updatedAt = ? WHERE profile = ? AND id = ?",
                binds: [.text(finalTitle), .double(now.timeIntervalSince1970), .text(profile.rawValue), .text(existing.uuidString)]
            )
        } else {
            let id = UUID()
            try exec(
                "INSERT INTO bookmarks (profile, id, title, urlString, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?)",
                binds: [.text(profile.rawValue), .text(id.uuidString), .text(finalTitle), .text(normalized), .double(now.timeIntervalSince1970), .double(now.timeIntervalSince1970)]
            )
        }
    }
    public func renameBookmark(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try exec(
            "UPDATE bookmarks SET title = ?, updatedAt = ? WHERE profile = ? AND id = ?",
            binds: [.text(trimmed), .double(Date().timeIntervalSince1970), .text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func removeBookmark(profile: BrowsingProfile, id: UUID) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec(
            "DELETE FROM bookmarks WHERE profile = ? AND id = ?",
            binds: [.text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func removeAllBookmarks(profile: BrowsingProfile) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec("DELETE FROM bookmarks WHERE profile = ?", binds: [.text(profile.rawValue)])
    }
    public func fetchHistory(profile: BrowsingProfile) async throws -> [BrowserHistoryItem] {
        try await ensureOpenAndMigratedIfNeeded()
        return try selectHistory(profile: profile)
    }
    public func recordHistoryVisit(profile: BrowsingProfile, urlString: String, title: String, at date: Date) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        // Dedupe behavior: if the most recent record is same URL within window, update timestamp/title.
        let dedupeWindow: TimeInterval = 12
        if let mostRecent = try selectMostRecentHistoryItem(profile: profile),
           mostRecent.urlString == normalized,
           abs(mostRecent.visitedAt.timeIntervalSince(date)) < dedupeWindow {
            let t = title.isEmpty ? mostRecent.title : title
            try exec(
                "UPDATE history SET title = ?, visitedAt = ? WHERE profile = ? AND id = ?",
                binds: [.text(t), .double(date.timeIntervalSince1970), .text(profile.rawValue), .text(mostRecent.id.uuidString)]
            )
            return
        }
        let t = title.isEmpty ? normalized : title
        let id = UUID()
        try exec(
            "INSERT INTO history (profile, id, title, urlString, visitedAt) VALUES (?, ?, ?, ?, ?)",
            binds: [.text(profile.rawValue), .text(id.uuidString), .text(t), .text(normalized), .double(date.timeIntervalSince1970)]
        )
    }
    public func updateMostRecentHistoryTitleIfNeeded(profile: BrowsingProfile, urlString: String, title: String) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !title.isEmpty else { return }
        guard let mostRecent = try selectMostRecentHistoryItem(profile: profile), mostRecent.urlString == normalized else { return }
        if mostRecent.title != title {
            try exec(
                "UPDATE history SET title = ? WHERE profile = ? AND id = ?",
                binds: [.text(title), .text(profile.rawValue), .text(mostRecent.id.uuidString)]
            )
        }
    }
    public func removeHistoryItem(profile: BrowsingProfile, id: UUID) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec(
            "DELETE FROM history WHERE profile = ? AND id = ?",
            binds: [.text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func removeAllHistory(profile: BrowsingProfile) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec("DELETE FROM history WHERE profile = ?", binds: [.text(profile.rawValue)])
    }
    public func fetchReadingList(profile: BrowsingProfile) async throws -> [BrowserReadingListItem] {
        try await ensureOpenAndMigratedIfNeeded()
        return try selectReadingList(profile: profile)
    }
    public func upsertReadingListItem(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        let finalTitle: String = {
            if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
            return normalized
        }()
        if let existing = try selectReadingListIDByURL(profile: profile, urlString: normalized) {
            try exec(
                "UPDATE reading_list SET title = ? WHERE profile = ? AND id = ?",
                binds: [.text(finalTitle), .text(profile.rawValue), .text(existing.uuidString)]
            )
        } else {
            let id = UUID()
            let now = Date()
            try exec(
                "INSERT INTO reading_list (profile, id, title, urlString, addedAt, lastOpenedAt, isRead) VALUES (?, ?, ?, ?, ?, NULL, 0)",
                binds: [.text(profile.rawValue), .text(id.uuidString), .text(finalTitle), .text(normalized), .double(now.timeIntervalSince1970)]
            )
        }
    }
    public func markReadingListRead(profile: BrowsingProfile, id: UUID, isRead: Bool) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec(
            "UPDATE reading_list SET isRead = ? WHERE profile = ? AND id = ?",
            binds: [.int(isRead ? 1 : 0), .text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func markReadingListOpened(profile: BrowsingProfile, id: UUID, at date: Date) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec(
            "UPDATE reading_list SET lastOpenedAt = ?, isRead = 1 WHERE profile = ? AND id = ?",
            binds: [.double(date.timeIntervalSince1970), .text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func renameReadingListItem(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        let trimmed = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        try exec(
            "UPDATE reading_list SET title = ? WHERE profile = ? AND id = ?",
            binds: [.text(trimmed), .text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func removeReadingListItem(profile: BrowsingProfile, id: UUID) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec(
            "DELETE FROM reading_list WHERE profile = ? AND id = ?",
            binds: [.text(profile.rawValue), .text(id.uuidString)]
        )
    }
    public func removeAllReadingList(profile: BrowsingProfile) async throws {
        try await ensureOpenAndMigratedIfNeeded()
        try exec("DELETE FROM reading_list WHERE profile = ?", binds: [.text(profile.rawValue)])
    }
    public func flush() async {
        // SQLite writes are immediate.
    }
    // MARK: - Open / Schema
    private func ensureOpenAndMigratedIfNeeded() async throws {
        if didOpen { return }
        try openDBIfPossible()
        try createSchemaIfNeeded()
        try await migrateLegacyJSONIfNeeded()
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
        // Pragmas: keep it simple + safe.
        try exec("PRAGMA journal_mode=WAL")
        try exec("PRAGMA synchronous=NORMAL")
        try exec("PRAGMA foreign_keys=ON")
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }
    private func createSchemaIfNeeded() throws {
        // Minimal versioning table.
        try exec("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
        // Bookmarks.
        try exec("""
        CREATE TABLE IF NOT EXISTS bookmarks (
            profile TEXT NOT NULL,
            id TEXT NOT NULL,
            title TEXT NOT NULL,
            urlString TEXT NOT NULL,
            createdAt REAL NOT NULL,
            updatedAt REAL NOT NULL,
            PRIMARY KEY (profile, id)
        )
        """)
        try exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_bookmarks_profile_url ON bookmarks(profile, urlString)")
        try exec("CREATE INDEX IF NOT EXISTS idx_bookmarks_profile_updatedAt ON bookmarks(profile, updatedAt DESC)")
        // History.
        try exec("""
        CREATE TABLE IF NOT EXISTS history (
            profile TEXT NOT NULL,
            id TEXT NOT NULL,
            title TEXT NOT NULL,
            urlString TEXT NOT NULL,
            visitedAt REAL NOT NULL,
            PRIMARY KEY (profile, id)
        )
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_history_profile_visitedAt ON history(profile, visitedAt DESC)")
        // Reading list.
        try exec("""
        CREATE TABLE IF NOT EXISTS reading_list (
            profile TEXT NOT NULL,
            id TEXT NOT NULL,
            title TEXT NOT NULL,
            urlString TEXT NOT NULL,
            addedAt REAL NOT NULL,
            lastOpenedAt REAL,
            isRead INTEGER NOT NULL,
            PRIMARY KEY (profile, id)
        )
        """)
        try exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_reading_profile_url ON reading_list(profile, urlString)")
        try exec("CREATE INDEX IF NOT EXISTS idx_reading_profile_addedAt ON reading_list(profile, addedAt DESC)")
        // Set schema version if missing.
        let version = try selectMetaInt(key: "schema_version")
        if version == nil {
            try exec("INSERT OR REPLACE INTO meta(key, value) VALUES('schema_version', '1')")
        }
    }
    private func migrateLegacyJSONIfNeeded() async throws {
        // Only for regular profile; private profile is non-persistent by design.
        if config.legacyBookmarksFilename != nil || config.legacyHistoryFilename != nil || config.legacyReadingListFilename != nil {
            // Best-effort: if DB is empty, import legacy snapshots.
            // This only runs once on first access.
        }
        // Import bookmarks.
        if let legacyBookmarksFilename, (try? selectBookmarks(profile: .regular).isEmpty) == true {
            let fileStore = JSONFileStoreActor()
            let snapshot: LegacyBookmarkSnapshot = await fileStore.load(
                filename: legacyBookmarksFilename,
                defaultValue: LegacyBookmarkSnapshot(items: [])
            )
            for item in snapshot.items {
                try exec(
                    "INSERT OR IGNORE INTO bookmarks (profile, id, title, urlString, createdAt, updatedAt) VALUES (?, ?, ?, ?, ?, ?)",
                    binds: [.text(BrowsingProfile.regular.rawValue), .text(item.id.uuidString), .text(item.title), .text(item.urlString), .double(item.createdAt.timeIntervalSince1970), .double(item.updatedAt.timeIntervalSince1970)]
                )
            }
        }
        // Import history.
        if let legacyHistoryFilename, (try? selectHistory(profile: .regular).isEmpty) == true {
            let fileStore = JSONFileStoreActor()
            let snapshot: LegacyHistorySnapshot = await fileStore.load(
                filename: legacyHistoryFilename,
                defaultValue: LegacyHistorySnapshot(items: [])
            )
            for item in snapshot.items {
                try exec(
                    "INSERT OR IGNORE INTO history (profile, id, title, urlString, visitedAt) VALUES (?, ?, ?, ?, ?)",
                    binds: [.text(BrowsingProfile.regular.rawValue), .text(item.id.uuidString), .text(item.title), .text(item.urlString), .double(item.visitedAt.timeIntervalSince1970)]
                )
            }
        }
        // Import reading list.
        if let legacyReadingListFilename, (try? selectReadingList(profile: .regular).isEmpty) == true {
            let fileStore = JSONFileStoreActor()
            let snapshot: LegacyReadingListSnapshot = await fileStore.load(
                filename: legacyReadingListFilename,
                defaultValue: LegacyReadingListSnapshot(items: [])
            )
            for item in snapshot.items {
                try exec(
                    "INSERT OR IGNORE INTO reading_list (profile, id, title, urlString, addedAt, lastOpenedAt, isRead) VALUES (?, ?, ?, ?, ?, ?, ?)",
                    binds: [
                        .text(BrowsingProfile.regular.rawValue),
                        .text(item.id.uuidString),
                        .text(item.title),
                        .text(item.urlString),
                        .double(item.addedAt.timeIntervalSince1970),
                        item.lastOpenedAt.map { .double($0.timeIntervalSince1970) } ?? .null,
                        .int(item.isRead ? 1 : 0)
                    ]
                )
            }
        }
    }
    private var legacyBookmarksFilename: String? { config.legacyBookmarksFilename }
    private var legacyHistoryFilename: String? { config.legacyHistoryFilename }
    private var legacyReadingListFilename: String? { config.legacyReadingListFilename }
    // MARK: - Legacy snapshot wrappers
    private struct LegacyBookmarkSnapshot: Codable, Sendable { var items: [BrowserBookmark] }
    private struct LegacyHistorySnapshot: Codable, Sendable { var items: [BrowserHistoryItem] }
    private struct LegacyReadingListSnapshot: Codable, Sendable { var items: [BrowserReadingListItem] }
    // MARK: - Queries
    private func selectBookmarks(profile: BrowsingProfile) throws -> [BrowserBookmark] {
        var result: [BrowserBookmark] = []
        try query(
            "SELECT id, title, urlString, createdAt, updatedAt FROM bookmarks WHERE profile = ? ORDER BY updatedAt DESC",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1),
                  let urlStr = sqlite3_column_text(stmt, 2) else { return }
            let created = sqlite3_column_double(stmt, 3)
            let updated = sqlite3_column_double(stmt, 4)
            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            let title = String(cString: titleStr)
            let url = String(cString: urlStr)
            result.append(
                BrowserBookmark(
                    id: id,
                    title: title,
                    urlString: url,
                    createdAt: Date(timeIntervalSince1970: created),
                    updatedAt: Date(timeIntervalSince1970: updated)
                )
            )
        }
        return result
    }
    private func selectBookmarkIDByURL(profile: BrowsingProfile, urlString: String) throws -> UUID? {
        var found: UUID?
        try query(
            "SELECT id FROM bookmarks WHERE profile = ? AND urlString = ? LIMIT 1",
            binds: [.text(profile.rawValue), .text(urlString)]
        ) { stmt in
            if let idStr = sqlite3_column_text(stmt, 0) {
                found = UUID(uuidString: String(cString: idStr))
            }
        }
        return found
    }
    private func selectHistory(profile: BrowsingProfile) throws -> [BrowserHistoryItem] {
        var result: [BrowserHistoryItem] = []
        try query(
            "SELECT id, title, urlString, visitedAt FROM history WHERE profile = ? ORDER BY visitedAt DESC",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1),
                  let urlStr = sqlite3_column_text(stmt, 2) else { return }
            let visited = sqlite3_column_double(stmt, 3)
            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            let title = String(cString: titleStr)
            let url = String(cString: urlStr)
            result.append(
                BrowserHistoryItem(
                    id: id,
                    title: title,
                    urlString: url,
                    visitedAt: Date(timeIntervalSince1970: visited)
                )
            )
        }
        return result
    }
    private func selectMostRecentHistoryItem(profile: BrowsingProfile) throws -> BrowserHistoryItem? {
        var found: BrowserHistoryItem?
        try query(
            "SELECT id, title, urlString, visitedAt FROM history WHERE profile = ? ORDER BY visitedAt DESC LIMIT 1",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1),
                  let urlStr = sqlite3_column_text(stmt, 2) else { return }
            let visited = sqlite3_column_double(stmt, 3)
            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            found = BrowserHistoryItem(
                id: id,
                title: String(cString: titleStr),
                urlString: String(cString: urlStr),
                visitedAt: Date(timeIntervalSince1970: visited)
            )
        }
        return found
    }
    private func selectReadingList(profile: BrowsingProfile) throws -> [BrowserReadingListItem] {
        var result: [BrowserReadingListItem] = []
        try query(
            "SELECT id, title, urlString, addedAt, lastOpenedAt, isRead FROM reading_list WHERE profile = ? ORDER BY addedAt DESC",
            binds: [.text(profile.rawValue)]
        ) { stmt in
            guard let idStr = sqlite3_column_text(stmt, 0),
                  let titleStr = sqlite3_column_text(stmt, 1),
                  let urlStr = sqlite3_column_text(stmt, 2) else { return }
            let added = sqlite3_column_double(stmt, 3)
            let lastOpenedIsNull = sqlite3_column_type(stmt, 4) == SQLITE_NULL
            let lastOpened = lastOpenedIsNull ? nil : Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4))
            let isRead = sqlite3_column_int(stmt, 5) != 0
            let id = UUID(uuidString: String(cString: idStr)) ?? UUID()
            result.append(
                BrowserReadingListItem(
                    id: id,
                    title: String(cString: titleStr),
                    urlString: String(cString: urlStr),
                    addedAt: Date(timeIntervalSince1970: added),
                    lastOpenedAt: lastOpened,
                    isRead: isRead
                )
            )
        }
        return result
    }
    private func selectReadingListIDByURL(profile: BrowsingProfile, urlString: String) throws -> UUID? {
        var found: UUID?
        try query(
            "SELECT id FROM reading_list WHERE profile = ? AND urlString = ? LIMIT 1",
            binds: [.text(profile.rawValue), .text(urlString)]
        ) { stmt in
            if let idStr = sqlite3_column_text(stmt, 0) {
                found = UUID(uuidString: String(cString: idStr))
            }
        }
        return found
    }
    private func selectMetaInt(key: String) throws -> Int? {
        var found: Int?
        try query("SELECT value FROM meta WHERE key = ? LIMIT 1", binds: [.text(key)]) { stmt in
            if let v = sqlite3_column_text(stmt, 0) {
                found = Int(String(cString: v))
            }
        }
        return found
    }
    // MARK: - SQLite plumbing
    private enum Bind {
        case text(String)
        case int(Int32)
        case double(Double)
        case null
    }
    private func exec(_ sql: String, binds: [Bind] = []) throws {
        #if canImport(SQLite3)
        var stmt: OpaquePointer?
        defer { if stmt != nil { sqlite3_finalize(stmt) } }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        try bindAll(stmt: stmt, binds: binds)
        if sqlite3_step(stmt) != SQLITE_DONE {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }
    private func query(_ sql: String, binds: [Bind] = [], row: (OpaquePointer) -> Void) throws {
        #if canImport(SQLite3)
        var stmt: OpaquePointer?
        defer { if stmt != nil { sqlite3_finalize(stmt) } }
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            throw LibraryRepositoryError.sqliteError(lastErrorMessage())
        }
        try bindAll(stmt: stmt, binds: binds)
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let stmt { row(stmt) }
        }
        #else
        throw LibraryRepositoryError.sqliteUnavailable
        #endif
    }
    private func bindAll(stmt: OpaquePointer?, binds: [Bind]) throws {
        #if canImport(SQLite3)
        for (index, bind) in binds.enumerated() {
            let idx = Int32(index + 1)
            let rc: Int32
            switch bind {
            case .text(let s):
                rc = sqlite3_bind_text(stmt, idx, s, -1, sqliteTransientDestructor)
            case .int(let i):
                rc = sqlite3_bind_int(stmt, idx, i)
            case .double(let d):
                rc = sqlite3_bind_double(stmt, idx, d)
            case .null:
                rc = sqlite3_bind_null(stmt, idx)
            }
            if rc != SQLITE_OK {
                throw LibraryRepositoryError.sqliteError(lastErrorMessage())
            }
        }
        #endif
    }
    private func lastErrorMessage() -> String {
        #if canImport(SQLite3)
        if let db, let c = sqlite3_errmsg(db) {
            return String(cString: c)
        }
        #endif
        return "Unknown SQLite error"
    }
}

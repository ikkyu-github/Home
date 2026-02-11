import Foundation
import SafariLikeCoreKit
@MainActor
enum LibraryStoreFactory {
    // SAFE SINGLETON (CACHED STATIC):
    // - Process-wide persistence components; intentionally shared across scenes.
    // - Must NOT store per-window/scene/tab runtime state (only DB/repo + browsing profile container).
    /// Shared repo/profile box per-process so bookmarks/history/reading list stay consistent.
    private static var shared: (repo: any LibraryRepository, profileBox: BrowsingProfileBox)?
    static func sharedRepository(
        legacyBookmarksFilename: String? = nil,
        legacyHistoryFilename: String? = nil,
        legacyReadingListFilename: String? = nil
    ) -> (any LibraryRepository, BrowsingProfileBox) {
        if let shared { return shared }
        let profileBox = BrowsingProfileBox(profile: .regular)
        let baseURL = LibraryStoreFactory.defaultLibraryDatabaseURL()
        let sqlite = SQLiteLibraryRepository(
            config: .init(
                databaseURL: baseURL,
                legacyBookmarksFilename: legacyBookmarksFilename,
                legacyHistoryFilename: legacyHistoryFilename,
                legacyReadingListFilename: legacyReadingListFilename
            )
        )
        let privateRepo = InMemoryLibraryRepository()
        // Route calls by explicit profile. Stores always pass profileBox.profile.
        let repo: any LibraryRepository = ProfiledLibraryRepository(
            regular: sqlite,
            privateRepo: privateRepo,
            currentProfile: { @MainActor @Sendable in profileBox.profile }
        )
        shared = (repo: repo, profileBox: profileBox)
        return (repo, profileBox)
    }
    static func makeStores() -> (profileBox: BrowsingProfileBox, bookmarks: BookmarkStore, history: HistoryStore, readingList: ReadingListStore) {
        let (repo, profileBox) = sharedRepository(
            legacyBookmarksFilename: "bookmarks.json",
            legacyHistoryFilename: "history.json",
            legacyReadingListFilename: "reading-list.json"
        )
        return (
            profileBox: profileBox,
            bookmarks: BookmarkStore(repository: repo, profileBox: profileBox),
            history: HistoryStore(repository: repo, profileBox: profileBox),
            readingList: ReadingListStore(repository: repo, profileBox: profileBox)
        )
    }
    private static func defaultLibraryDatabaseURL() -> URL {
        let base: URL = {
            if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                return appSupport
            }
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                return docs
            }
            return FileManager.default.temporaryDirectory
        }()
        let dir = base.appendingPathComponent("SafariLikeKit", isDirectory: true)
        return dir.appendingPathComponent("library.sqlite", isDirectory: false)
    }
}

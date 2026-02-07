// BUILD-PERF-AUDIT(2026-01-21): Preview-only helpers.
// Keep out of non-Debug builds to reduce compilation scope.
#if DEBUG
import Foundation
import SafariLikeCoreKit
extension BookmarkStore {
    static var preview: BookmarkStore {
        let profileBox = BrowsingProfileBox(profile: .regular)
        let repo = InMemoryLibraryRepository(
            regularBookmarks: [
                BrowserBookmark(title: "Example", urlString: "https://example.com"),
                BrowserBookmark(title: "Apple", urlString: "https://apple.com")
            ]
        )
        return BookmarkStore(repository: repo, profileBox: profileBox)
    }
}
extension HistoryStore {
    static var preview: HistoryStore {
        let profileBox = BrowsingProfileBox(profile: .regular)
        let repo = InMemoryLibraryRepository(
            regularHistory: [
                BrowserHistoryItem(title: "Example", urlString: "https://example.com", visitedAt: Date()),
                BrowserHistoryItem(title: "Apple", urlString: "https://apple.com", visitedAt: Date().addingTimeInterval(-3600))
            ]
        )
        return HistoryStore(repository: repo, profileBox: profileBox)
    }
}
extension ReadingListStore {
    static var preview: ReadingListStore {
        let profileBox = BrowsingProfileBox(profile: .regular)
        let repo = InMemoryLibraryRepository(
            regularReadingList: [
                BrowserReadingListItem(title: "Swift.org", urlString: "https://swift.org"),
                BrowserReadingListItem(title: "Example", urlString: "https://example.com")
            ]
        )
        return ReadingListStore(repository: repo, profileBox: profileBox)
    }
}
// TODO: WebsitePreferencesStore preview moved to SafariLikeUIKit
// Since WebsitePreferencesStore is now in SafariLikeUIKit, the preview extension
// must be defined there instead.
#endif

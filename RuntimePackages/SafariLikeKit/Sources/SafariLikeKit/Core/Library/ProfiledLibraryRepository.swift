import Foundation
import SafariLikeCoreKit
public struct ProfiledLibraryRepository: LibraryRepository {
    private let regular: any LibraryRepository
    private let privateRepo: any LibraryRepository
    private let currentProfile: @MainActor () -> BrowsingProfile
    public init(
        regular: any LibraryRepository,
        privateRepo: any LibraryRepository,
        currentProfile: @escaping @MainActor () -> BrowsingProfile
    ) {
        self.regular = regular
        self.privateRepo = privateRepo
        self.currentProfile = currentProfile
    }
    private func repoAndProfile() async -> (any LibraryRepository, BrowsingProfile) {
        let profile = await MainActor.run { currentProfile() }
        return (profile == .private ? privateRepo : regular, profile)
    }
    public func fetchBookmarks(profile: BrowsingProfile) async throws -> [BrowserBookmark] {
        try await (profile == .private ? privateRepo : regular).fetchBookmarks(profile: profile)
    }
    public func upsertBookmark(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        try await (profile == .private ? privateRepo : regular).upsertBookmark(profile: profile, title: title, urlString: urlString)
    }
    public func renameBookmark(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        try await (profile == .private ? privateRepo : regular).renameBookmark(profile: profile, id: id, newTitle: newTitle)
    }
    public func removeBookmark(profile: BrowsingProfile, id: UUID) async throws {
        try await (profile == .private ? privateRepo : regular).removeBookmark(profile: profile, id: id)
    }
    public func removeAllBookmarks(profile: BrowsingProfile) async throws {
        try await (profile == .private ? privateRepo : regular).removeAllBookmarks(profile: profile)
    }
    public func fetchHistory(profile: BrowsingProfile) async throws -> [BrowserHistoryItem] {
        try await (profile == .private ? privateRepo : regular).fetchHistory(profile: profile)
    }
    public func recordHistoryVisit(profile: BrowsingProfile, urlString: String, title: String, at date: Date) async throws {
        try await (profile == .private ? privateRepo : regular).recordHistoryVisit(profile: profile, urlString: urlString, title: title, at: date)
    }
    public func updateMostRecentHistoryTitleIfNeeded(profile: BrowsingProfile, urlString: String, title: String) async throws {
        try await (profile == .private ? privateRepo : regular).updateMostRecentHistoryTitleIfNeeded(profile: profile, urlString: urlString, title: title)
    }
    public func removeHistoryItem(profile: BrowsingProfile, id: UUID) async throws {
        try await (profile == .private ? privateRepo : regular).removeHistoryItem(profile: profile, id: id)
    }
    public func removeAllHistory(profile: BrowsingProfile) async throws {
        try await (profile == .private ? privateRepo : regular).removeAllHistory(profile: profile)
    }
    public func fetchReadingList(profile: BrowsingProfile) async throws -> [BrowserReadingListItem] {
        try await (profile == .private ? privateRepo : regular).fetchReadingList(profile: profile)
    }
    public func upsertReadingListItem(profile: BrowsingProfile, title: String?, urlString: String) async throws {
        try await (profile == .private ? privateRepo : regular).upsertReadingListItem(profile: profile, title: title, urlString: urlString)
    }
    public func markReadingListRead(profile: BrowsingProfile, id: UUID, isRead: Bool) async throws {
        try await (profile == .private ? privateRepo : regular).markReadingListRead(profile: profile, id: id, isRead: isRead)
    }
    public func markReadingListOpened(profile: BrowsingProfile, id: UUID, at date: Date) async throws {
        try await (profile == .private ? privateRepo : regular).markReadingListOpened(profile: profile, id: id, at: date)
    }
    public func renameReadingListItem(profile: BrowsingProfile, id: UUID, newTitle: String) async throws {
        try await (profile == .private ? privateRepo : regular).renameReadingListItem(profile: profile, id: id, newTitle: newTitle)
    }
    public func removeReadingListItem(profile: BrowsingProfile, id: UUID) async throws {
        try await (profile == .private ? privateRepo : regular).removeReadingListItem(profile: profile, id: id)
    }
    public func removeAllReadingList(profile: BrowsingProfile) async throws {
        try await (profile == .private ? privateRepo : regular).removeAllReadingList(profile: profile)
    }
    public func flush() async {
        await regular.flush()
        await privateRepo.flush()
    }
    // MARK: Convenience (profile picked at call time)
    public func fetchBookmarks() async throws -> [BrowserBookmark] {
        let (_, p) = await repoAndProfile()
        return try await fetchBookmarks(profile: p)
    }
}

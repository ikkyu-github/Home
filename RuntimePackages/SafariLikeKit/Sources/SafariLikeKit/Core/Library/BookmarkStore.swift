import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
public final class BookmarkStore: ObservableObject {
    @Published private(set) var items: [BrowserBookmark]
    private let repository: any LibraryRepository
    private let profileBox: BrowsingProfileBox
    private var cancellables = Set<AnyCancellable>()
    init(repository: any LibraryRepository, profileBox: BrowsingProfileBox) {
        self.repository = repository
        self.profileBox = profileBox
        self.items = []
        profileBox.$profile
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
        reload()
    }
    /// Convenience initializer kept for legacy callers.
    /// Uses the default SQLite-backed repo for regular and an in-memory repo for private.
    public convenience init(filename: String = "bookmarks.json") {
        let (repo, profileBox) = LibraryStoreFactory.sharedRepository(legacyBookmarksFilename: filename)
        self.init(repository: repo, profileBox: profileBox)
    }
    public func saveNow() {
        Task { await repository.flush() }
    }
    public func addOrUpdate(title: String?, urlString: String) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.upsertBookmark(profile: profile, title: title, urlString: urlString)
                await MainActor.run { self?.reload() }
            } catch {
                // Swallow errors for now; callers are UI.
            }
        }
    }
    public func rename(id: UUID, newTitle: String) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.renameBookmark(profile: profile, id: id, newTitle: newTitle)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func remove(id: UUID) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeBookmark(profile: profile, id: id)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func removeAll() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeAllBookmarks(profile: profile)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    private func reload() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                let items = try await self?.repository.fetchBookmarks(profile: profile) ?? []
                await MainActor.run { self?.items = items }
            } catch {
            }
        }
    }
}

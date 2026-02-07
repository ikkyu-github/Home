import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
public final class ReadingListStore: ObservableObject {
    @Published private(set) var items: [BrowserReadingListItem]
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
    public convenience init(filename: String = "reading-list.json") {
        let (repo, profileBox) = LibraryStoreFactory.sharedRepository(legacyReadingListFilename: filename)
        self.init(repository: repo, profileBox: profileBox)
    }
    public func saveNow() {
        Task { await repository.flush() }
    }
    public func addOrUpdate(title: String?, urlString: String) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.upsertReadingListItem(profile: profile, title: title, urlString: urlString)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func markRead(id: UUID, isRead: Bool) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.markReadingListRead(profile: profile, id: id, isRead: isRead)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func markOpened(id: UUID) {
        let profile = profileBox.profile
        let now = Date()
        Task { [weak self] in
            do {
                try await self?.repository.markReadingListOpened(profile: profile, id: id, at: now)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func rename(id: UUID, newTitle: String) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.renameReadingListItem(profile: profile, id: id, newTitle: newTitle)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func remove(id: UUID) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeReadingListItem(profile: profile, id: id)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func removeAll() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeAllReadingList(profile: profile)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    private func reload() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                let items = try await self?.repository.fetchReadingList(profile: profile) ?? []
                await MainActor.run { self?.items = items }
            } catch {
            }
        }
    }
}

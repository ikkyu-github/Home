import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
public final class HistoryStore: ObservableObject {
    @Published private(set) var items: [BrowserHistoryItem]
    private let repository: any LibraryRepository
    private let profileBox: BrowsingProfileBox
    private var cancellables = Set<AnyCancellable>()
    /// If the same URL is recorded too frequently (e.g. redirects), we dedupe within this window.
    private let dedupeWindow: TimeInterval = 12
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
    public convenience init(filename: String = "history.json") {
        let (repo, profileBox) = LibraryStoreFactory.sharedRepository(legacyHistoryFilename: filename)
        self.init(repository: repo, profileBox: profileBox)
    }
    public func saveNow() {
        Task { await repository.flush() }
    }
    public func recordVisit(urlString: String, title: String, at date: Date) {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        // Dedupe: if the most recent entry is the same URL and too recent, just update timestamp/title.
        // Keep in-memory behavior consistent (fast UI feedback) while persisting via repository.
        if var first = items.first,
           first.urlString == normalized,
           abs(first.visitedAt.timeIntervalSince(date)) < dedupeWindow {
            first.visitedAt = date
            if !title.isEmpty { first.title = title }
            items[0] = first
        } else {
            let t = title.isEmpty ? normalized : title
            let newItem = BrowserHistoryItem(title: t, urlString: normalized, visitedAt: date)
            items.insert(newItem, at: 0)
        }
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.recordHistoryVisit(profile: profile, urlString: normalized, title: title, at: date)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    /// When the title arrives later than the URL, we can patch the most recent record.
    public func updateMostRecentTitleIfNeeded(urlString: String, title: String) {
        let normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !title.isEmpty else { return }
        guard let first = items.first, first.urlString == normalized else { return }
        if first.title != title {
            var updated = first
            updated.title = title
            items[0] = updated
        }
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.updateMostRecentHistoryTitleIfNeeded(profile: profile, urlString: normalized, title: title)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func remove(id: UUID) {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeHistoryItem(profile: profile, id: id)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    public func removeAll() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                try await self?.repository.removeAllHistory(profile: profile)
                await MainActor.run { self?.reload() }
            } catch {
            }
        }
    }
    private func reload() {
        let profile = profileBox.profile
        Task { [weak self] in
            do {
                let items = try await self?.repository.fetchHistory(profile: profile) ?? []
                await MainActor.run { self?.items = items }
            } catch {
            }
        }
    }
}

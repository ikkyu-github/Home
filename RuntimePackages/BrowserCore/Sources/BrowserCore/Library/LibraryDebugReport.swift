import Foundation
import SafariLikeContracts

public struct LibraryDebugReport: Codable, Sendable {
    public var profile: LibraryProfile
    public var historyEntryCount: Int
    public var bookmarkNodeCount: Int
    public var readingListCount: Int
    public var topSiteOverrideCount: Int
    public var lastSuggestionLatencyMs: Double?

    public init(
        profile: LibraryProfile,
        historyEntryCount: Int,
        bookmarkNodeCount: Int,
        readingListCount: Int,
        topSiteOverrideCount: Int,
        lastSuggestionLatencyMs: Double?
    ) {
        self.profile = profile
        self.historyEntryCount = historyEntryCount
        self.bookmarkNodeCount = bookmarkNodeCount
        self.readingListCount = readingListCount
        self.topSiteOverrideCount = topSiteOverrideCount
        self.lastSuggestionLatencyMs = lastSuggestionLatencyMs
    }
}

public actor LibraryDiagnostics {
    private let repository: any LibraryRepository
    private var lastSuggestionLatencyMs: Double?

    public init(repository: any LibraryRepository) {
        self.repository = repository
    }

    public func setLastSuggestionLatency(_ ms: Double) {
        lastSuggestionLatencyMs = ms
    }

    public func report(profile: LibraryProfile) async -> LibraryDebugReport? {
        guard profile == .regular else {
            return LibraryDebugReport(
                profile: profile,
                historyEntryCount: 0,
                bookmarkNodeCount: 0,
                readingListCount: 0,
                topSiteOverrideCount: 0,
                lastSuggestionLatencyMs: nil
            )
        }
        do {
            let c = try await repository.counts(profile: profile)
            return LibraryDebugReport(
                profile: profile,
                historyEntryCount: c.historyVisits,
                bookmarkNodeCount: c.bookmarks,
                readingListCount: c.readingList,
                topSiteOverrideCount: c.topSiteOverrides,
                lastSuggestionLatencyMs: lastSuggestionLatencyMs
            )
        } catch {
            return nil
        }
    }
}

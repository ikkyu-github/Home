import Foundation
import SafariLikeContracts

public actor HistoryEngine {
    public struct Configuration: Sendable {
        public var dedupeWindowSeconds: TimeInterval
        public init(dedupeWindowSeconds: TimeInterval = 12) {
            self.dedupeWindowSeconds = dedupeWindowSeconds
        }
    }

    private let repository: any LibraryRepository
    private let normalizer: URLStringNormalizer
    private let config: Configuration

    // Per-profile recent visit cache to reduce redirect spam.
    private var lastVisitByProfile: [LibraryProfile: (url: String, at: Date)] = [:]

    public init(repository: any LibraryRepository, normalizer: URLStringNormalizer = URLStringNormalizer(), config: Configuration = Configuration()) {
        self.repository = repository
        self.normalizer = normalizer
        self.config = config
    }

    public func recordNavigationCommit(profile: LibraryProfile, urlString: String, title: String?, at date: Date = Date()) async {
        guard profile == .regular else {
            // Private: no history writes.
            return
        }
        guard let canonical = normalizer.canonicalize(urlString) else { return }

        if let last = lastVisitByProfile[profile],
           last.url == canonical.normalized,
           abs(last.at.timeIntervalSince(date)) < config.dedupeWindowSeconds {
            // Ignore duplicates in short window.
            return
        }
        lastVisitByProfile[profile] = (canonical.normalized, date)

        do {
            try await repository.recordHistoryVisit(profile: profile, url: canonical, title: title ?? "", at: date)
        } catch {
            // Best-effort; diagnostics can be layered later.
        }
    }

    public func query(profile: LibraryProfile, query: String, limit: Int) async -> [HistoryEntry] {
        guard profile == .regular else { return [] }
        do {
            return try await repository.queryHistory(profile: profile, query: query, limit: limit)
        } catch {
            return []
        }
    }

    public func clear(profile: LibraryProfile, since: Date?) async {
        guard profile == .regular else { return }
        do {
            try await repository.clearHistory(profile: profile, since: since)
        } catch {
        }
    }
}

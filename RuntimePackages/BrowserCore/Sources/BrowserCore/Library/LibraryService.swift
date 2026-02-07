import Foundation
import SafariLikeContracts

/// Process-owned, dependency-injected facade for library engines.
public actor LibraryService {
    public struct Configuration: Sendable {
        public var suggestionsMaxResults: Int
        public init(suggestionsMaxResults: Int = 12) {
            self.suggestionsMaxResults = suggestionsMaxResults
        }
    }

    public let history: HistoryEngine
    public let topSites: TopSitesEngine
    public let suggestions: SuggestionsEngine
    public let diagnostics: LibraryDiagnostics

    private let config: Configuration

    public init(repository: any LibraryRepository, config: Configuration = Configuration()) {
        self.config = config
        let normalizer = URLStringNormalizer()
        let history = HistoryEngine(repository: repository, normalizer: normalizer)
        let topSites = TopSitesEngine(repository: repository)
        let suggestions = SuggestionsEngine(
            repository: repository,
            historyEngine: history,
            topSitesEngine: topSites,
            normalizer: normalizer,
            config: .init(maxResults: config.suggestionsMaxResults)
        )
        self.history = history
        self.topSites = topSites
        self.suggestions = suggestions
        self.diagnostics = LibraryDiagnostics(repository: repository)
    }

    public func suggest(profile: LibraryProfile, query: String, openTabs: [OpenTabSnapshot]) async -> [SuggestionItem] {
        let start = CFAbsoluteTimeGetCurrent()
        let out = await suggestions.suggest(profile: profile, query: query, openTabs: openTabs)
        let end = CFAbsoluteTimeGetCurrent()
        let ms = (end - start) * 1000.0
        await diagnostics.setLastSuggestionLatency(ms)
        return out
    }
}

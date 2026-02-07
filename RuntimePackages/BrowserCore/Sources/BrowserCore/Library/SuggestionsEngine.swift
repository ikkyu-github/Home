import Foundation
import SafariLikeContracts

public struct OpenTabSnapshot: Sendable, Hashable {
    public var title: String
    public var urlString: String

    public init(title: String, urlString: String) {
        self.title = title
        self.urlString = urlString
    }
}

public actor SuggestionsEngine {
    public struct Configuration: Sendable {
        public var maxResults: Int
        public var perSourceCap: Int
        public init(maxResults: Int = 12, perSourceCap: Int = 8) {
            self.maxResults = maxResults
            self.perSourceCap = perSourceCap
        }
    }

    private let repository: any LibraryRepository
    private let history: HistoryEngine
    private let topSites: TopSitesEngine
    private let normalizer: URLStringNormalizer
    private let config: Configuration

    public init(
        repository: any LibraryRepository,
        historyEngine: HistoryEngine,
        topSitesEngine: TopSitesEngine,
        normalizer: URLStringNormalizer = URLStringNormalizer(),
        config: Configuration = Configuration()
    ) {
        self.repository = repository
        self.history = historyEngine
        self.topSites = topSitesEngine
        self.normalizer = normalizer
        self.config = config
    }

    public func suggest(
        profile: LibraryProfile,
        query: String,
        openTabs: [OpenTabSnapshot]
    ) async -> [SuggestionItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        guard profile == .regular else {
            // Strict: no suggestion leaks in private.
            return []
        }

        // Tabs snapshot is already in-memory.
        let tabItems: [SuggestionItem] = buildTabSuggestions(query: q, openTabs: openTabs)

        // Note: even though these are independent sources, the current repository implementation
        // is SQLite-backed and actor-isolated; running these sequentially avoids stressing
        // concurrent cross-actor access patterns that can surface allocator crashes.
        let h = await history.query(profile: profile, query: q, limit: config.perSourceCap)
        let b = (try? await repository.queryBookmarks(profile: profile, query: q, limit: config.perSourceCap)) ?? []
        let r = (try? await repository.queryReadingList(profile: profile, query: q, limit: config.perSourceCap)) ?? []
        let ts = await topSites.computeTopSites(profile: profile)

        var out: [SuggestionItem] = []
        out.reserveCapacity(config.maxResults)

        // Score and merge
        out.append(contentsOf: tabItems)
        out.append(contentsOf: buildHistorySuggestions(query: q, entries: h))
        out.append(contentsOf: buildBookmarkSuggestions(query: q, nodes: b))
        out.append(contentsOf: buildReadingListSuggestions(query: q, items: r))
        out.append(contentsOf: buildTopSiteSuggestions(query: q, sites: ts))

        // De-dupe by canonical URL.
        var seen: Set<String> = []
        var deduped: [SuggestionItem] = []
        for s in out.sorted(by: sortComparator) {
            let key = s.url.normalized
            if seen.contains(key) { continue }
            seen.insert(key)
            deduped.append(s)
            if deduped.count >= config.maxResults { break }
        }
        return deduped
    }

    // MARK: - Scoring

    /// Deterministic sorting: higher score first, stable tie-break by type then url.
    private func sortComparator(_ a: SuggestionItem, _ b: SuggestionItem) -> Bool {
        if a.rankScore != b.rankScore { return a.rankScore > b.rankScore }
        if a.type != b.type { return a.type.rawValue < b.type.rawValue }
        return a.url.normalized < b.url.normalized
    }

    private func scoreMatch(query: String, title: String, url: CanonicalURL, base: Double, recencyDays: Double? = nil, frequency: Int? = nil, favorite: Bool = false, pinned: Bool = false, openTab: Bool = false) -> Double {
        let q = query.lowercased()
        let t = title.lowercased()
        let u = url.normalized.lowercased()

        var score = base

        // Exact/prefix boosts.
        if t == q || u == q { score += 8 }
        if t.hasPrefix(q) { score += 4 }
        if u.contains(q) { score += 2 }
        if url.host.lowercased().hasPrefix(q) { score += 3 }

        // Recency/frequency.
        if let recencyDays {
            score += exp(-max(0, recencyDays) / 7.0) * 4.0
        }
        if let frequency {
            score += min(10.0, log(Double(max(1, frequency))) * 2.0)
        }

        if favorite { score += 6 }
        if pinned { score += 5 }
        if openTab { score += 3 }

        return score
    }

    private func buildTabSuggestions(query: String, openTabs: [OpenTabSnapshot]) -> [SuggestionItem] {
        let q = query.lowercased()
        var items: [SuggestionItem] = []
        for tab in openTabs {
            guard let cu = normalizer.canonicalize(tab.urlString) else { continue }
            let title = tab.title.isEmpty ? cu.host : tab.title
            // Match heuristic.
            let hit = title.lowercased().contains(q) || cu.normalized.lowercased().contains(q) || cu.host.lowercased().contains(q)
            guard hit else { continue }
            let s = scoreMatch(query: query, title: title, url: cu, base: 20, openTab: true)
            items.append(
                SuggestionItem(
                    type: .tab,
                    title: title,
                    subtitle: cu.host,
                    url: cu,
                    iconToken: "tab",
                    rankScore: s
                )
            )
        }
        return items
    }

    private func buildHistorySuggestions(query: String, entries: [HistoryEntry]) -> [SuggestionItem] {
        let now = Date()
        return entries.compactMap { e in
            let days = max(0.0, now.timeIntervalSince(e.lastVisitedAt) / 86400.0)
            let s = scoreMatch(query: query, title: e.title, url: e.url, base: 10, recencyDays: days, frequency: e.visitCount)
            return SuggestionItem(
                type: .history,
                title: e.title,
                subtitle: e.url.host,
                url: e.url,
                iconToken: "history",
                rankScore: s
            )
        }
    }

    private func buildBookmarkSuggestions(query: String, nodes: [BookmarkNode]) -> [SuggestionItem] {
        return nodes.compactMap { n in
            guard n.type == .bookmark, let url = n.url else { return nil }
            let s = scoreMatch(query: query, title: n.title, url: url, base: 14, favorite: n.isFavorite)
            return SuggestionItem(
                type: .bookmark,
                title: n.title,
                subtitle: url.host,
                url: url,
                iconToken: n.isFavorite ? "favorite" : "bookmark",
                rankScore: s
            )
        }
    }

    private func buildReadingListSuggestions(query: String, items: [ReadingListItem]) -> [SuggestionItem] {
        return items.map { i in
            let s = scoreMatch(query: query, title: i.title, url: i.url, base: 9)
            return SuggestionItem(
                type: .readingList,
                title: i.title,
                subtitle: i.url.host,
                url: i.url,
                iconToken: "readingList",
                rankScore: s
            )
        }
    }

    private func buildTopSiteSuggestions(query: String, sites: [TopSite]) -> [SuggestionItem] {
        let q = query.lowercased()
        let filtered = sites.filter { site in
            let title = site.title?.lowercased() ?? ""
            return site.url.normalized.lowercased().contains(q) || site.url.host.lowercased().contains(q) || title.contains(q)
        }
        return filtered.map { site in
            let title = site.title ?? site.url.host
            let s = scoreMatch(query: query, title: title, url: site.url, base: 8, pinned: site.isPinned)
            return SuggestionItem(
                type: .topSite,
                title: title,
                subtitle: site.url.host,
                url: site.url,
                iconToken: site.isPinned ? "pinned" : "topSite",
                rankScore: s
            )
        }
    }
}

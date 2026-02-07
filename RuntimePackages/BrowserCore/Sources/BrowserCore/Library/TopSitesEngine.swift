import Foundation
import SafariLikeContracts

public actor TopSitesEngine {
    public struct Configuration: Sendable {
        public var maxItems: Int
        public var lookbackDays: Int
        public init(maxItems: Int = 12, lookbackDays: Int = 30) {
            self.maxItems = maxItems
            self.lookbackDays = lookbackDays
        }
    }

    private let repository: any LibraryRepository
    private let config: Configuration

    public init(repository: any LibraryRepository, config: Configuration = Configuration()) {
        self.repository = repository
        self.config = config
    }

    public func computeTopSites(profile: LibraryProfile, now: Date = Date()) async -> [TopSite] {
        guard profile == .regular else { return [] }

        let since = Calendar(identifier: .gregorian).date(byAdding: .day, value: -config.lookbackDays, to: now) ?? now.addingTimeInterval(-Double(config.lookbackDays) * 86400)

        let signals: [(url: CanonicalURL, title: String?, visitCount: Int, lastVisitedAt: Date)]
        do {
            signals = try await repository.topSiteSignals(profile: profile, since: since, limit: 500)
        } catch {
            return []
        }

        let overrides: [TopSiteOverride]
        do {
            overrides = try await repository.fetchTopSiteOverrides(profile: profile)
        } catch {
            return []
        }

        var overrideByURL: [String: TopSiteOverride] = [:]
        for o in overrides { overrideByURL[o.url.normalized] = o }

        // Score: frequency + recency decay.
        // Deterministic: no randomness; stable tie-break by normalized url.
        func score(visitCount: Int, lastVisitedAt: Date) -> Double {
            let days = max(0.0, now.timeIntervalSince(lastVisitedAt) / 86400.0)
            let recency = exp(-days / 7.0) // half-ish around a week
            return Double(visitCount) * 0.7 + recency * 3.0
        }

        var candidates: [TopSite] = []
        candidates.reserveCapacity(signals.count)

        for s in signals {
            if let o = overrideByURL[s.url.normalized], o.isHidden { continue }
            let base = score(visitCount: s.visitCount, lastVisitedAt: s.lastVisitedAt)
            let pinned = overrideByURL[s.url.normalized]?.isPinned ?? false
            let orderIndex = overrideByURL[s.url.normalized]?.orderIndex
            let title = overrideByURL[s.url.normalized]?.title ?? s.title
            candidates.append(
                TopSite(
                    url: s.url,
                    title: title,
                    score: base,
                    isPinned: pinned,
                    orderIndex: orderIndex
                )
            )
        }

        // Ensure pinned-only entries can exist even if not in signals.
        for o in overrides where o.isPinned {
            if candidates.contains(where: { $0.url.normalized == o.url.normalized }) { continue }
            candidates.append(
                TopSite(
                    url: o.url,
                    title: o.title,
                    score: 0,
                    isPinned: true,
                    orderIndex: o.orderIndex
                )
            )
        }

        // Sort:
        // 1) pinned first
        // 2) pinned with orderIndex ascending, then score
        // 3) non-pinned by score
        // 4) tie-break by normalized URL
        let sorted = candidates.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned && !b.isPinned }
            if a.isPinned && b.isPinned {
                if let ao = a.orderIndex, let bo = b.orderIndex, ao != bo { return ao < bo }
                if (a.orderIndex != nil) != (b.orderIndex != nil) { return a.orderIndex != nil }
            }
            if a.score != b.score { return a.score > b.score }
            return a.url.normalized < b.url.normalized
        }

        // Compact pinned orderIndex to keep UI reorder simple.
        var out: [TopSite] = []
        out.reserveCapacity(min(config.maxItems, sorted.count))
        var pinnedIndex = 0
        for var s in sorted {
            if out.count >= config.maxItems { break }
            if s.isPinned {
                s.orderIndex = pinnedIndex
                pinnedIndex += 1
            } else {
                s.orderIndex = nil
            }
            out.append(s)
        }
        return out
    }

    public func setPinned(profile: LibraryProfile, url: CanonicalURL, isPinned: Bool) async {
        guard profile == .regular else { return }
        do {
            // preserve existing title/order if present
            let existing = try await repository.fetchTopSiteOverrides(profile: profile).first(where: { $0.url.normalized == url.normalized })
            let o = TopSiteOverride(
                url: url,
                isPinned: isPinned,
                orderIndex: existing?.orderIndex,
                isHidden: existing?.isHidden ?? false,
                title: existing?.title
            )
            try await repository.upsertTopSiteOverride(profile: profile, overrideValue: o)
        } catch {
        }
    }

    public func hide(profile: LibraryProfile, url: CanonicalURL) async {
        guard profile == .regular else { return }
        do {
            let existing = try await repository.fetchTopSiteOverrides(profile: profile).first(where: { $0.url.normalized == url.normalized })
            let o = TopSiteOverride(
                url: url,
                isPinned: existing?.isPinned ?? false,
                orderIndex: existing?.orderIndex,
                isHidden: true,
                title: existing?.title
            )
            try await repository.upsertTopSiteOverride(profile: profile, overrideValue: o)
        } catch {
        }
    }

    public func reorderPinned(profile: LibraryProfile, urlsInOrder: [CanonicalURL]) async {
        guard profile == .regular else { return }
        do {
            let existing = try await repository.fetchTopSiteOverrides(profile: profile)
            var byURL: [String: TopSiteOverride] = [:]
            for o in existing { byURL[o.url.normalized] = o }
            for (idx, url) in urlsInOrder.enumerated() {
                let old = byURL[url.normalized]
                let o = TopSiteOverride(
                    url: url,
                    isPinned: true,
                    orderIndex: idx,
                    isHidden: old?.isHidden ?? false,
                    title: old?.title
                )
                try await repository.upsertTopSiteOverride(profile: profile, overrideValue: o)
            }
        } catch {
        }
    }
}

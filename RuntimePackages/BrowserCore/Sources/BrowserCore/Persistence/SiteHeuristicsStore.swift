import Foundation

/// Compatibility shim for the legacy `SiteHeuristicsStore` API.
///
/// The source of truth remains `SiteHeuristicsStoreActor`. This actor maintains a small
/// in-memory cache that is refreshed asynchronously on-demand.
public actor SiteHeuristicsStore {

    public struct SiteRecord: Codable, Equatable, Sendable {
        public var lastCrashAt: Date?
        public var crashCountWindow: Int
        public var heavyMemoryScore: Int

        public var requiresPersistentStore: Bool
        public var privacySensitive: Bool
        public var frequentCrossSiteNav: Bool

        public init(
            lastCrashAt: Date? = nil,
            crashCountWindow: Int = 0,
            heavyMemoryScore: Int = 30,
            requiresPersistentStore: Bool = false,
            privacySensitive: Bool = false,
            frequentCrossSiteNav: Bool = false
        ) {
            self.lastCrashAt = lastCrashAt
            self.crashCountWindow = crashCountWindow
            self.heavyMemoryScore = heavyMemoryScore
            self.requiresPersistentStore = requiresPersistentStore
            self.privacySensitive = privacySensitive
            self.frequentCrossSiteNav = frequentCrossSiteNav
        }

        internal init(model: SiteHeuristicsModel) {
            self.lastCrashAt = model.lastCrashAt
            self.crashCountWindow = model.crashCount
            self.heavyMemoryScore = model.memoryHotnessScore
            self.requiresPersistentStore = model.privacyFlags.requiresPersistentStorage
            self.privacySensitive = model.privacyFlags.isSensitive
            self.frequentCrossSiteNav = model.privacyFlags.isTracking
        }
    }

    /// SAFE SINGLETON:
    /// - Process-wide domain store keyed by site/URL, intentionally shared across scenes.
    /// - Must not store per-window/scene/tab identifiers.
    public static let shared = SiteHeuristicsStore()

    private let refreshInterval: TimeInterval = 5

    private var cachedBySiteKey: [String: SiteRecord] = [:]
    private var lastRefreshBySiteKey: [String: Date] = [:]

    public init() {}

    /// Best-effort record fetch.
    ///
    /// Returns the cached record immediately (or a default), and schedules an async refresh
    /// if the cache is missing or stale.
    public func record(for siteKey: String) async -> SiteRecord {
        let now = Date()

        let record = cachedBySiteKey[siteKey] ?? SiteRecord()
        let last = lastRefreshBySiteKey[siteKey] ?? .distantPast
        let shouldRefresh = now.timeIntervalSince(last) >= refreshInterval

        if shouldRefresh {
            lastRefreshBySiteKey[siteKey] = now
            Task(priority: .utility) { [weak self] in
                guard let self else { return }
                await self.refresh(siteKey: siteKey)
            }
        }

        return record
    }

    private func refresh(siteKey: String) async {
        let model = await SiteHeuristicsRuntime.store.heuristics(for: siteKey)
        cachedBySiteKey[siteKey] = SiteRecord(model: model)
    }
}

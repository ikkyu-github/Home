import Foundation

/// Actor-based thread-safe store for site heuristics and policies.
/// Provides async read/write access with caching to minimize contention.
/// 
/// Owns the single source of truth for per-site data.
public actor SiteHeuristicsStoreActor {
    
    // MARK: - Constants
    
    private static let dataKey = "SafariLike.SiteHeuristics.v1"
    private static let legacyDataKey = "SafariLike.SiteHeuristics.records.v1"
    private static let schemaVersion = 1
    private static let maxCacheSizeBytes = 5_000_000 // 5MB max

    public typealias Mutation = @Sendable (inout SiteHeuristicsModel) -> Void
    
    // MARK: - State
    
    private var cache: [String: SiteHeuristicsModel]
    private let userDefaults: UserDefaults
    private var lastPersistTime: Date = .distantPast
    private let persistThrottle: TimeInterval = 2.0 // Batch writes within 2s
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        let result = Self.loadFromDisk(userDefaults: userDefaults)
        self.cache = result.cache

        if result.didMigrateLegacy {
            // Persist migrated data eagerly and clear legacy storage.
            if let data = try? JSONEncoder().encode(self.cache) {
                userDefaults.set(data, forKey: Self.dataKey)
            }
            userDefaults.removeObject(forKey: Self.legacyDataKey)
        }
    }
    
    // MARK: - Public API
    
    /// Fetch heuristics for a site, or return default if not found.
    public func heuristics(for siteKey: String) -> SiteHeuristicsModel {
        cache[siteKey] ?? SiteHeuristicsModel(siteKey: siteKey)
    }
    
    /// Update heuristics for a site (async-safe).
    public func updateHeuristics(for siteKey: String, mutate: Mutation) {
        var model = cache[siteKey] ?? SiteHeuristicsModel(siteKey: siteKey)
        mutate(&model)
        cache[siteKey] = model
        
        // Throttled persistence
        if Date().timeIntervalSince(lastPersistTime) >= persistThrottle {
            persistToDiskLocked()
            lastPersistTime = Date()
        }
    }
    
    /// Batch update multiple sites efficiently.
    public func updateMultiple(_ updates: [String: Mutation]) {
        for (siteKey, mutate) in updates {
            var model = cache[siteKey] ?? SiteHeuristicsModel(siteKey: siteKey)
            mutate(&model)
            cache[siteKey] = model
        }
        persistToDiskLocked()
        lastPersistTime = Date()
    }
    
    /// Record a crash for a site
    public func recordCrash(for siteKey: String) {
        updateHeuristics(for: siteKey) { model in
            model.crashCount = min(100, model.crashCount + 1)
            model.lastCrashAt = Date()
            model.lastSeenAt = Date()
            // Increase memory hotness when crashes occur
            model.memoryHotnessScore = min(100, model.memoryHotnessScore + 10)
        }
    }
    
    /// Record a restore failure
    public func recordRestoreFailure(for siteKey: String) {
        updateHeuristics(for: siteKey) { model in
            model.restoreFailureCount = min(100, model.restoreFailureCount + 1)
            model.lastSeenAt = Date()
        }
    }
    
    /// Record load time observation (running average)
    public func recordLoadTime(for siteKey: String, ms: Double) {
        updateHeuristics(for: siteKey) { model in
            // Exponential moving average: 80% old, 20% new
            if model.avgLoadTimeMs == 0 {
                model.avgLoadTimeMs = ms
            } else {
                model.avgLoadTimeMs = model.avgLoadTimeMs * 0.8 + ms * 0.2
            }
            model.lastSeenAt = Date()
        }
    }
    
    /// Mark a site as media-heavy
    public func markMediaHeavy(for siteKey: String) {
        updateHeuristics(for: siteKey) { model in
            model.isMediaHeavy = true
            model.lastSeenAt = Date()
        }
    }
    
    /// Decay old metrics (call periodically, e.g., daily)
    public func decayMetrics() {
        let now = Date()
        let oneDayAgo = now.addingTimeInterval(-86400)
        
        for key in cache.keys {
            if cache[key]?.lastSeenAt ?? .distantPast < oneDayAgo {
                updateHeuristics(for: key) { model in
                    // Decay crash count: 50% reduction per day of inactivity
                    model.crashCount = max(0, model.crashCount - 1)
                    // Decay memory score slowly
                    model.memoryHotnessScore = max(30, model.memoryHotnessScore - 2)
                }
            }
        }
    }
    
    /// Clear all heuristics (for testing or privacy reset)
    public func clearAll() {
        cache.removeAll()
        userDefaults.removeObject(forKey: Self.dataKey)
    }
    
    /// Get cache statistics for debugging
    public func cacheStats() -> (count: Int, estimatedBytes: Int) {
        let estimatedBytes = cache.values.reduce(0) { $0 + estimatedSize(of: $1) }
        return (count: cache.count, estimatedBytes: estimatedBytes)
    }
    
    // MARK: - Private Helpers
    
    private func persistToDiskLocked() {
        guard let data = try? JSONEncoder().encode(cache) else {
            return
        }
        userDefaults.set(data, forKey: Self.dataKey)
    }

    private struct LoadResult {
        var cache: [String: SiteHeuristicsModel]
        var didMigrateLegacy: Bool
    }

    private struct LegacySiteRecordV1: Codable {
        var lastCrashAt: Date?
        var crashCountWindow: Int
        var heavyMemoryScore: Int
        var requiresPersistentStore: Bool
        var privacySensitive: Bool
        var frequentCrossSiteNav: Bool
    }

    private static func loadFromDisk(userDefaults: UserDefaults) -> LoadResult {
        if let data = userDefaults.data(forKey: dataKey),
           let decoded = try? JSONDecoder().decode([String: SiteHeuristicsModel].self, from: data) {
            let migrated = decoded.mapValues { model in
                var updated = model
                if updated.schemaVersion < schemaVersion {
                    updated.schemaVersion = schemaVersion
                }
                return updated
            }
            return LoadResult(cache: migrated, didMigrateLegacy: false)
        }

        // Legacy migration (v0 -> v1): UserDefaults-based SiteRecord dictionary.
        if let legacyData = userDefaults.data(forKey: legacyDataKey),
           let legacyDecoded = try? JSONDecoder().decode([String: LegacySiteRecordV1].self, from: legacyData) {
            let now = Date()
            var migrated: [String: SiteHeuristicsModel] = [:]
            migrated.reserveCapacity(legacyDecoded.count)

            for (siteKey, legacy) in legacyDecoded {
                var model = SiteHeuristicsModel(siteKey: siteKey)
                model.avgLoadTimeMs = 0
                model.crashCount = min(100, max(0, legacy.crashCountWindow))
                model.lastCrashAt = legacy.lastCrashAt
                model.restoreFailureCount = 0
                model.memoryHotnessScore = min(100, max(0, legacy.heavyMemoryScore))
                model.isMediaHeavy = false
                model.prefersDesktopMode = nil
                model.privacyFlags = .init(
                    isTracking: legacy.frequentCrossSiteNav,
                    requiresPersistentStorage: legacy.requiresPersistentStore,
                    isSensitive: legacy.privacySensitive
                )
                model.lastSeenAt = legacy.lastCrashAt ?? now
                model.schemaVersion = schemaVersion
                migrated[siteKey] = model
            }

            return LoadResult(cache: migrated, didMigrateLegacy: true)
        }

        return LoadResult(cache: [:], didMigrateLegacy: false)
    }
    
    private func estimatedSize(of model: SiteHeuristicsModel) -> Int {
        // Rough estimate: ~500 bytes per record
        500
    }
}

import Foundation

/// Collects metrics from runtime events and feeds them to the heuristics store.
///
/// Acts as a bridge between SafariLikeCoreKit runtime observers and the
/// SiteHeuristicsStoreActor. Coordinates metric aggregation.
public final class HeuristicsMetricsCollector: Sendable {
    
    private nonisolated let store: SiteHeuristicsStoreActor
    private nonisolated let engine: HeuristicsEngine
    
    public init(
        store: SiteHeuristicsStoreActor,
        engine: HeuristicsEngine = .init()
    ) {
        self.store = store
        self.engine = engine
    }
    
    // MARK: - Metric Collection API
    
    /// Record a successful navigation (load commit time).
    /// Called from WebKit navigation delegate.
    public func recordNavigation(
        siteKey: String,
        loadTimeMs: Double
    ) async {
        await store.updateHeuristics(for: siteKey) { model in
            let updated = engine.update(
                model: model,
                with: HeuristicsEngine.Metrics(observedAt: Date(), loadTimeMs: loadTimeMs)
            )
            model = updated
        }
    }
    
    /// Record a web process crash or termination.
    /// Called from WebKit process pool observer.
    public func recordCrash(siteKey: String) async {
        await store.updateHeuristics(for: siteKey) { model in
            let updated = engine.update(
                model: model,
                with: HeuristicsEngine.Metrics(observedAt: Date(), didCrash: true)
            )
            model = updated
        }
    }
    
    /// Record a restore failure (navigation didn't complete).
    /// Called from tab restore logic.
    public func recordRestoreFailure(siteKey: String) async {
        await store.updateHeuristics(for: siteKey) { model in
            let updated = engine.update(
                model: model,
                with: HeuristicsEngine.Metrics(observedAt: Date(), restoreFailed: true)
            )
            model = updated
        }
    }
    
    /// Mark site as media-heavy (detected video/audio).
    /// Called from media playback detector.
    public func recordMediaHeavySite(siteKey: String) async {
        await store.updateHeuristics(for: siteKey) { model in
            let updated = engine.update(
                model: model,
                with: HeuristicsEngine.Metrics(observedAt: Date(), isMediaHeavy: true)
            )
            model = updated
        }
    }
    
    /// Record memory pressure observation for a site.
    /// Called from memory monitor when threshold crossed.
    public func recordMemoryPressure(siteKey: String, score: Int) async {
        await store.updateHeuristics(for: siteKey) { model in
            let updated = engine.update(
                model: model,
                with: HeuristicsEngine.Metrics(observedAt: Date(), memoryHotnessScore: score)
            )
            model = updated
        }
    }
    
    /// Batch record multiple navigation events (efficient for bulk operations).
    public func recordNavigations(events: [(siteKey: String, loadTimeMs: Double)]) async {
        var updates: [String: SiteHeuristicsStoreActor.Mutation] = [:]
        
        for (siteKey, loadTimeMs) in events {
            updates[siteKey] = { (model: inout SiteHeuristicsModel) in
                let updated = self.engine.update(
                    model: model,
                    with: HeuristicsEngine.Metrics(observedAt: Date(), loadTimeMs: loadTimeMs)
                )
                model = updated
            }
        }
        
        await store.updateMultiple(updates)
    }
    
    // MARK: - Policy Computation
    
    /// Compute current policy for a site (pure computation + cache lookup).
    /// Fast enough to call from main thread.
    public func computePolicy(for siteKey: String) async -> SitePolicy {
        let model = await store.heuristics(for: siteKey)
        return engine.computePolicy(from: model)
    }
    
    /// Batch compute policies (efficient).
    public func computePolicies(
        for siteKeys: [String]
    ) async -> [String: SitePolicy] {
        var models: [String: SiteHeuristicsModel] = [:]
        
        for siteKey in siteKeys {
            models[siteKey] = await store.heuristics(for: siteKey)
        }
        
        return engine.computePolicies(from: models)
    }
    
    // MARK: - Diagnostics
    
    /// Get health score for debugging UI
    public func healthScore(for siteKey: String) async -> Int {
        let model = await store.heuristics(for: siteKey)
        return engine.healthScore(from: model)
    }
    
    /// Get full heuristics for diagnostic logging
    public func heuristics(for siteKey: String) async -> SiteHeuristicsModel {
        await store.heuristics(for: siteKey)
    }
    
    // MARK: - Maintenance
    
    /// Decay old metrics (call periodically, e.g., daily).
    /// Reduces sensitivity to old crashes/load times.
    public func decayMetrics() async {
        await store.decayMetrics()
    }
    
    /// Clear all heuristics (for testing or user privacy reset).
    public func clearAll() async {
        await store.clearAll()
    }
}

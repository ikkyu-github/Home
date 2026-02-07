import Foundation

/// Extension to SessionRestorePlan for per-site heuristics-aware restoration.
///
/// Determines which tabs should be prewarmed before navigation based on site policies.
public extension SessionRestorePlan {
    
    /// Compute which tabs should be prewarmed based on site heuristics.
    /// Called during restore planning to optimize responsiveness.
    func computePrewarmCandidates(
        using engine: HeuristicsEngine,
        store: SiteHeuristicsStoreActor
    ) async -> [UUID] {
        // Extract tab URLs from initial state
        var urlBySiteKey: [String: [UUID]] = [:]
        
        for window in initialState.windows {
            for pane in window.panes {
                for tab in pane.tabOrder {
                    let siteKey = SiteHeuristicsModel.normalizeSiteKey(from: tab.url)
                    if urlBySiteKey[siteKey] == nil {
                        urlBySiteKey[siteKey] = []
                    }
                    urlBySiteKey[siteKey]?.append(tab.tabID)
                }
            }
        }
        
        var preWarmTabIDs: [UUID] = []
        
        // Check policy for each site
        for (siteKey, tabIDs) in urlBySiteKey {
            let heuristics = await store.heuristics(for: siteKey)
            let policy = engine.computePolicy(from: heuristics)
            
            // If site supports prewarming, include its tabs
            if policy.allowPrewarmWebView {
                preWarmTabIDs.append(contentsOf: tabIDs)
            }
        }
        
        return preWarmTabIDs
    }
    
    /// Enrich plan with prewarm information.
    /// Returns a tuple: (defer for performance, prewarm for responsiveness)
    struct EnrichedPlan: Sendable {
        /// Tabs that should be deferred (low priority, loaded later)
        public var deferredTabIDs: [UUID]
        
        /// Tabs that should be prewarmed (high priority, setup early)
        public var preWarmTabIDs: [UUID]
        
        /// Tabs that should be restored normally (everything else)
        public var normalRestoreTabIDs: [UUID]
        
        public init(
            deferredTabIDs: [UUID],
            preWarmTabIDs: [UUID],
            normalRestoreTabIDs: [UUID]
        ) {
            self.deferredTabIDs = deferredTabIDs
            self.preWarmTabIDs = preWarmTabIDs
            self.normalRestoreTabIDs = normalRestoreTabIDs
        }
    }
    
    /// Enrich this restore plan with per-site policy information.
    func enrich(
        using engine: HeuristicsEngine,
        store: SiteHeuristicsStoreActor
    ) async -> EnrichedPlan {
        let preWarmCandidates = await computePrewarmCandidates(using: engine, store: store)
        
        let allTabIDs: Set<UUID> = Set(
            initialState.windows.flatMap { window in
                window.panes.flatMap { $0.tabOrder.map { $0.tabID } }
            }
        )
        let deferrals = Set(deferredNavigationTabIDs)
        let preWarmSet = Set(preWarmCandidates)
        
        let deferredTabIDs = Array(deferrals)
        let preWarmTabIDs = Array(preWarmSet.subtracting(deferrals))
        let normalRestoreTabIDs = Array(allTabIDs.subtracting(deferrals).subtracting(preWarmSet))
        
        return EnrichedPlan(
            deferredTabIDs: deferredTabIDs,
            preWarmTabIDs: preWarmTabIDs,
            normalRestoreTabIDs: normalRestoreTabIDs
        )
    }
}

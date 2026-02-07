import Foundation

/// RenderQuotaManager: Central authority for WebView render budgeting (Safari-like)
/// - Enforces max 2 active WebViews (split or single)
/// - All WebView lifecycle changes must go through this manager
/// - Policy: If over quota, freeze/snapshot/discard as needed
/// - Architecture: Decouples logical tab state from visual render state
/// - Why: Safari iPad never renders >2 webviews; this prevents jank/memory spikes
public final class RenderQuotaManager {
    public static let maxActiveWebViews = 2

    /// Tabs currently allowed to have a live WebView
    private(set) var activeTabIDs: [UUID] = []
    /// Tabs that are frozen (snapshot only)
    private(set) var frozenTabIDs: Set<UUID> = []
    /// Tabs that are evicted (destroyed WebView)
    private(set) var evictedTabIDs: Set<UUID> = []

    /// Called by TabManager when tab state changes or orientation changes
    public func updateQuota(policyDecision: BrowserCore.RenderBudgetPolicy.Decision) {
        // Only allow up to maxActiveWebViews
        activeTabIDs = Array(policyDecision.keepRendered.prefix(Self.maxActiveWebViews))
        frozenTabIDs = policyDecision.freeze
        evictedTabIDs = policyDecision.evict
    }

    /// Query if a tab should have a live WebView
    public func isTabActive(_ tabID: UUID) -> Bool {
        activeTabIDs.contains(tabID)
    }

    /// Query if a tab should be frozen (snapshot only)
    public func isTabFrozen(_ tabID: UUID) -> Bool {
        frozenTabIDs.contains(tabID)
    }

    /// Query if a tab should be evicted (destroy WebView)
    public func isTabEvicted(_ tabID: UUID) -> Bool {
        evictedTabIDs.contains(tabID)
    }
}

// Architecture comment:
// - RenderQuotaManager is the single source of truth for WebView render authority.
// - All view creation/destruction must consult this manager.
// - This matches Safari iPad: never more than 2 live webviews, others are frozen/snapshotted.
// - Prevents SwiftUI from triggering excess WebView creation via body/layout changes.

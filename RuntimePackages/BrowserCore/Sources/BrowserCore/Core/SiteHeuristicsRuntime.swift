import Foundation

/// Shared runtime for per-site heuristics.
///
/// This provides a single, process-wide source of truth (actor-backed) and a
/// lightweight API surface for higher layers to record metrics and query policies.
public enum SiteHeuristicsRuntime {
    public static let store = SiteHeuristicsStoreActor()
    public static let engine = HeuristicsEngine()
    public static let collector = HeuristicsMetricsCollector(store: store, engine: engine)
}

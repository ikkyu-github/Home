import Foundation
import SafariLikeCoreKit
/// App-level registry of active per-scene runtime contexts.
///
/// This is the single mutable source of truth for scene-scoped runtime state.
///
/// Threading: main-actor only.
@MainActor
final class SceneRuntimeRegistry {
    internal private(set) var contexts: [SceneID: SceneRuntimeContext] = [:]
    private let siteHeuristicsStore: SiteHeuristicsStore
    init(siteHeuristicsStore: SiteHeuristicsStore) {
        self.siteHeuristicsStore = siteHeuristicsStore
    }
    /// Return an existing context for a scene.
    ///
    /// Contexts are created during scene registration (connect) and removed during
    /// unregister (disconnect). Calling this before registration is a programmer error.
    func context(for sceneID: SceneID) -> SceneRuntimeContext {
        if let existing = contexts[sceneID] { return existing }
        preconditionFailure("SceneRuntimeRegistry has no context for sceneID=\(sceneID.raw). Ensure the scene is registered before requesting its runtime context.")
    }
    /// Remove a scene context and aggressively release all WKWebViews.
    func remove(sceneID: SceneID) {
        guard let context = contexts.removeValue(forKey: sceneID) else { return }
        context.shutdownAndReleaseWebViews()
    }
    // MARK: - Internal (creation)
    func ensureContext(sceneID: SceneID, tabManager: TabManager, core: SafariLikeCoreKit.SceneRuntimeContext) -> SceneRuntimeContext {
        if let existing = contexts[sceneID] { return existing }
        _ = siteHeuristicsStore
        let created = SceneRuntimeContext(sceneID: sceneID, tabManager: tabManager, core: core)
        contexts[sceneID] = created
        return created
    }
}

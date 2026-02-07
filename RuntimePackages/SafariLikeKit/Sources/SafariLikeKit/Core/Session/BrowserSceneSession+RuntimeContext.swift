import Foundation
import SafariLikeCoreKit
@MainActor
extension BrowserSceneSession {
    /// Create a scene-scoped runtime context for this session.
    ///
    /// Prefer supplying a registry-owned context from your app composition root when you have
    /// a multi-window registry. This helper exists to support UIKit hosts and simple embeddings.
    public func makeSceneRuntimeContext(siteHeuristicsStore: SiteHeuristicsStore) -> SceneRuntimeContext {
        let manager = viewModel.tabManager
        let core = SafariLikeCoreKit.SceneRuntimeContext(
            sceneIdentifier: sceneID,
            windowID: manager.windowID,
            tabRegistry: manager.normalTabRegistry,
            privateTabRegistry: manager.privateTabRegistry,
            siteHeuristicsStore: siteHeuristicsStore,
            websiteDataPolicy: .default
        )
        return SceneRuntimeContext(
            sceneID: SceneID(raw: sceneID),
            tabManager: manager,
            core: core
        )
    }
}

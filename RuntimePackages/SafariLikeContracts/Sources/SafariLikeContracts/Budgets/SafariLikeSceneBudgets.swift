import Foundation

/// Scene-scoped budgets that higher layers (App/SafariLikeKit) may apply.
///
/// Contract:
/// - These are *overrides* only. CoreKit remains the source of truth for defaults via `BrowserPolicy`.
/// - Prefer setting stricter values than CoreKit defaults; do not exceed them without a policy change.
/// - Keep UI-framework free.
public struct SafariLikeSceneBudgets: Sendable, Equatable {
    /// Optional stricter cap for max *alive* WebViews in memory for regular browsing.
    public var maxAliveWebViewsRegularOverride: Int?

    /// Optional stricter cap for max *alive* WebViews in memory for private browsing.
    public var maxAliveWebViewsPrivateOverride: Int?

    /// Optional stricter cap for max *concurrent active* WebViews in a scene.
    ///
    /// If nil, CoreKit uses `BrowserPolicy.maxConcurrentViews`.
    public var maxConcurrentActiveWebViewsOverride: Int?

    /// Optional cap for snapshot cache entries per scene (if a snapshot cache is present).
    public var maxSnapshotsPerSceneOverride: Int?

    public init(
        maxAliveWebViewsRegularOverride: Int? = nil,
        maxAliveWebViewsPrivateOverride: Int? = nil,
        maxConcurrentActiveWebViewsOverride: Int? = nil,
        maxSnapshotsPerSceneOverride: Int? = nil
    ) {
        self.maxAliveWebViewsRegularOverride = maxAliveWebViewsRegularOverride
        self.maxAliveWebViewsPrivateOverride = maxAliveWebViewsPrivateOverride
        self.maxConcurrentActiveWebViewsOverride = maxConcurrentActiveWebViewsOverride
        self.maxSnapshotsPerSceneOverride = maxSnapshotsPerSceneOverride
    }
}

import SwiftUI

/// Safe-area resolution rule (SafariLikeKit):
/// - Prefer SceneMetrics-derived insets (stable/safe) as the single source of truth.
/// - Use GeometryReader insets only as a fallback when SceneMetrics reports all zeros.
internal enum ResolvedInsetsProvider {
    static func resolve(sceneInsets: EdgeInsets, geometryInsets: EdgeInsets) -> EdgeInsets {
        let sanitizedScene = sanitize(sceneInsets)
        let sanitizedGeometry = sanitize(geometryInsets)

        if hasAnyNonZeroComponent(sanitizedScene) {
            return sanitizedScene
        }
        return sanitizedGeometry
    }

    private static func sanitize(_ insets: EdgeInsets) -> EdgeInsets {
        EdgeInsets(
            top: max(0, insets.top),
            leading: max(0, insets.leading),
            bottom: max(0, insets.bottom),
            trailing: max(0, insets.trailing)
        )
    }

    private static func hasAnyNonZeroComponent(_ insets: EdgeInsets) -> Bool {
        let epsilon: CGFloat = 0.0001
        return insets.top > epsilon
            || insets.leading > epsilon
            || insets.bottom > epsilon
            || insets.trailing > epsilon
    }
}

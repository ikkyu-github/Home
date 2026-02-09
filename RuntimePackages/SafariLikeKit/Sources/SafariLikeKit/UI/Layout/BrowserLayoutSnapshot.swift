import SwiftUI
import UIKit

internal struct ChromeHeightLimits: Equatable {
    let min: CGFloat
    let max: CGFloat
}

/// Single source of truth for per-frame browser layout inputs and resolved policy.
///
/// Owned by `BrowserView`: created once per GeometryReader evaluation and
/// passed down to layout + overlay subtrees to avoid re-deriving insets and
/// chrome policy in multiple places.
internal struct BrowserLayoutSnapshot {
    let containerSize: CGSize

    /// Insets actually used for layout/hit-testing decisions.
    /// Computed by `ChromeController.effectiveSafeAreaInsets(provided:geometryInsets:)`.
    let effectiveSafeAreaInsets: EdgeInsets

    /// Scene-level stable insets sourced from UIWindow/UIScene.
    /// This is intentionally UIEdgeInsets to match `SceneMetrics`.
    let stableInsets: UIEdgeInsets

    /// Raw insets reported by SwiftUI `GeometryProxy.safeAreaInsets`.
    let geometrySafeAreaInsets: EdgeInsets

    /// Chrome policy resolved for the current frame.
    let resolvedChromeStyle: BrowserChromeStyle

    /// Optional min/max chrome height constraints resolved from stable metrics.
    let chromeHeightLimits: ChromeHeightLimits?

    /// Optional lift applied when keyboard is visible and policy requires it.
    let keyboardLift: CGFloat?

    /// Layout mode / orientation result from `BrowserLayoutResolver`.
    let layoutResolution: BrowserLayoutResolution

    var isLandscape: Bool { layoutResolution.isLandscape }
    var safeWidth: CGFloat { layoutResolution.safeWidth }

    var stableEdgeInsets: EdgeInsets {
        EdgeInsets(
            top: stableInsets.top,
            leading: stableInsets.left,
            bottom: stableInsets.bottom,
            trailing: stableInsets.right
        )
    }
}

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

    /// Lift applied when keyboard is visible and policy requires it.
    /// Single source of truth for all chrome/layout consumers.
    let keyboardLift: CGFloat

    /// Whether the URL bar is focused for the current frame.
    let isURLBarFocused: Bool

    /// Height of the top chrome (header) for this frame.
    let chromeTopHeight: CGFloat

    /// Height of the bottom chrome (phone portrait bottom bar) for this frame.
    /// Excludes `keyboardLift`.
    let chromeBottomHeight: CGFloat

    /// Total height occupied at the bottom edge when including `keyboardLift`.
    var chromeBottomOccupiedHeight: CGFloat { chromeBottomHeight + keyboardLift }

    /// Total vertical space occupied by chrome + keyboard lift.
    var chromeTotalOccupiedHeight: CGFloat { chromeTopHeight + chromeBottomOccupiedHeight }

    /// Insets that define the interactive/content viewport for this frame.
    /// Use this instead of re-deriving chrome + keyboard offsets in multiple layers.
    let contentViewportInsets: EdgeInsets

    /// Layout mode / orientation result from `BrowserLayoutResolver`.
    let layoutResolution: BrowserLayoutResolution

    /// 0...1 Tab Overview presentation progress for the current frame.
    /// Owned by root transition controller; snapped into this per-frame snapshot.
    let tabOverviewPresentationProgress: CGFloat

    /// Tab Overview visibility state as of the current frame.
    let isTabOverviewVisible: Bool

    /// Whether Tab Overview is currently being dragged interactively.
    let isDraggingTabOverview: Bool

    var isLandscape: Bool { layoutResolution.isLandscape }
    var safeWidth: CGFloat { layoutResolution.safeWidth }

    var tabOverviewProgressClamped: CGFloat {
        max(0, min(1, tabOverviewPresentationProgress))
    }

    var stableEdgeInsets: EdgeInsets {
        EdgeInsets(
            top: stableInsets.top,
            leading: stableInsets.left,
            bottom: stableInsets.bottom,
            trailing: stableInsets.right
        )
    }
}

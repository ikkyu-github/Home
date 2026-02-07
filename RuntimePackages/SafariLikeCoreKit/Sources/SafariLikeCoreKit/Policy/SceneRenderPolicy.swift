import CoreGraphics

/// Safari-like render authority for deciding how many primary panes may be rendered
/// and whether tab overview is allowed.
///
/// Architecture intent:
/// - SwiftUI views must not be the decision-maker for core layout behavior.
/// - Decisions are pure (no UIKit/WebKit), deterministic, and testable.
/// - UI layers consume the decision and merely render the resulting slots.
public enum SceneRenderPolicy {

    public enum DeviceClass: Sendable {
        case phone
        case pad
    }

    public enum Orientation: Sendable {
        case portrait
        case landscape
    }

    public struct Input: Sendable {
        public let orientation: Orientation
        public let deviceClass: DeviceClass

        /// Available render size for the browser content.
        ///
        /// Note: callers should pass a *stable* scene/window-derived size. If you subtract safe-area
        /// insets, do it before constructing this input so policy stays UIKit-free.
        public let availableSize: CGSize

        /// User intent (e.g. Split button).
        public let wantsSplit: Bool

        public init(
            orientation: Orientation,
            deviceClass: DeviceClass,
            availableSize: CGSize,
            wantsSplit: Bool
        ) {
            self.orientation = orientation
            self.deviceClass = deviceClass
            self.availableSize = availableSize
            self.wantsSplit = wantsSplit
        }
    }

    public struct Decision: Sendable, Equatable {
        /// 1 = single pane, 2 = split panes.
        public let maxRenderedViews: Int

        /// When false, UI must not open tab overview (and must cancel it if already open).
        public let isTabOverviewAllowed: Bool

        public init(maxRenderedViews: Int, isTabOverviewAllowed: Bool) {
            self.maxRenderedViews = maxRenderedViews
            self.isTabOverviewAllowed = isTabOverviewAllowed
        }
    }

    /// Decide render behavior for the current scene.
    ///
    /// Required Safari-like invariant:
    /// - Landscape + single-pane => tab overview is forbidden.
    public static func decide(_ input: Input) -> Decision {
        let canSplitByWidth = SplitCapabilityPolicy.canPresentSplit(for: input.availableSize.width)
        let isSplit = input.wantsSplit && canSplitByWidth

        let maxRenderedViews = isSplit ? 2 : 1

        // Safari-like: in landscape, a single-pane should be a full-bleed browsing surface.
        // Allowing overview here tends to introduce reserved-space/layout instability during rotation.
        let isTabOverviewAllowed: Bool = {
            if input.orientation == .landscape, maxRenderedViews == 1 {
                return false
            }
            return true
        }()

        _ = input.deviceClass // reserved for future idiom-specific tuning

        return Decision(maxRenderedViews: maxRenderedViews, isTabOverviewAllowed: isTabOverviewAllowed)
    }
}

/// Width-only capability check for presenting split UI.
///
/// Kept in CoreKit so render authority can be consistent across UIKit/SwiftUI layers.
public enum SplitCapabilityPolicy {
    public static func canPresentSplit(for availableWidth: CGFloat) -> Bool {
        // Matches the previous UI-only SplitViewPolicy threshold.
        availableWidth >= 390
    }
}

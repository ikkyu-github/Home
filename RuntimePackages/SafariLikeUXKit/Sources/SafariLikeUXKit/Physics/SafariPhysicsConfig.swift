import CoreGraphics

/// Centralized gesture/animation tuning for Safari-like feel.
///
/// Design goals:
/// - Single source of truth for thresholds and distances
/// - Pure numeric config (no SwiftUI dependencies)
/// - Deterministic decisions (no time/random)
public struct SafariPhysicsConfig: Sendable {

    public struct Spring: Sendable, Equatable {
        public var response: Double
        public var dampingFraction: Double

        public init(response: Double, dampingFraction: Double) {
            self.response = response
            self.dampingFraction = dampingFraction
        }
    }

    public struct Overview: Sendable, Equatable {
        /// The gesture distance (pt) that maps to progress 0→1.
        public var openDistance: CGFloat

        /// Decision threshold using *current* progress (0..1).
        public var settleThreshold: CGFloat

        /// Decision threshold using *projected* progress (0..1) derived from predicted end.
        public var projectedSettleThreshold: CGFloat

        /// Ignore tiny drags.
        public var deadZone: CGFloat

        public init(
            openDistance: CGFloat,
            settleThreshold: CGFloat,
            projectedSettleThreshold: CGFloat,
            deadZone: CGFloat
        ) {
            self.openDistance = openDistance
            self.settleThreshold = settleThreshold
            self.projectedSettleThreshold = projectedSettleThreshold
            self.deadZone = deadZone
        }
    }

    public struct TabOverviewCard: Sendable, Equatable {
        public var closeThresholdX: CGFloat
        public var dismissThresholdY: CGFloat
        public var maxDragX: CGFloat
        public var maxDragY: CGFloat

        public init(
            closeThresholdX: CGFloat,
            dismissThresholdY: CGFloat,
            maxDragX: CGFloat,
            maxDragY: CGFloat
        ) {
            self.closeThresholdX = closeThresholdX
            self.dismissThresholdY = dismissThresholdY
            self.maxDragX = maxDragX
            self.maxDragY = maxDragY
        }
    }

    public var overviewSpring: Spring
    public var overview: Overview
    public var tabOverviewCard: TabOverviewCard

    public init(
        overviewSpring: Spring,
        overview: Overview,
        tabOverviewCard: TabOverviewCard
    ) {
        self.overviewSpring = overviewSpring
        self.overview = overview
        self.tabOverviewCard = tabOverviewCard
    }

    /// Safari-like overview open distance.
    /// - iPhone widths clamp to ~320
    /// - iPad widths land in ~520–680 depending on width
    public static func resolvedOverviewOpenDistance(containerWidth: CGFloat) -> CGFloat {
        let w = max(0, containerWidth)
        // Scale with width but clamp to the Safari-like band.
        // 0.75x makes iPad drags feel "weighted" without being sluggish.
        let proposed = w * 0.75
        return min(680, max(320, proposed))
    }

    public static let `default` = SafariPhysicsConfig(
        overviewSpring: .init(response: 0.33, dampingFraction: 0.90),
        overview: .init(
            // Updated at runtime based on container width (see resolvedOverviewOpenDistance).
            openDistance: 600,
            settleThreshold: 0.50,
            projectedSettleThreshold: 0.52,
            deadZone: 8
        ),
        tabOverviewCard: .init(
            closeThresholdX: 120,
            dismissThresholdY: 140,
            maxDragX: 220,
            maxDragY: 260
        )
    )
}

    extension SafariPhysicsConfig.TabOverviewCard {

        public enum Axis: Equatable, Sendable {
            case horizontal
            case vertical
        }

        public enum Outcome: Equatable, Sendable {
            case reset
            case close(direction: CGFloat)
            case dismiss
        }

        public func dominantAxis(dx: CGFloat, dy: CGFloat) -> Axis {
            abs(dx) > abs(dy) ? .horizontal : .vertical
        }

        public func decideEnd(dx: CGFloat, dy: CGFloat) -> Outcome {
            switch dominantAxis(dx: dx, dy: dy) {
            case .horizontal:
                if abs(dx) >= closeThresholdX {
                    return .close(direction: dx >= 0 ? 1 : -1)
                }
                return .reset

            case .vertical:
                if dy >= dismissThresholdY, abs(dy) > abs(dx) {
                    return .dismiss
                }
                return .reset
            }
        }
    }

extension SafariPhysicsConfig: Equatable {}


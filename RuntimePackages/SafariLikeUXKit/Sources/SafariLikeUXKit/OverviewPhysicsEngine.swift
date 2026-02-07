import CoreGraphics

/// Pure-data overview/gesture physics utilities.
///
/// This consolidates the "math" behind:
/// - Tab overview layout (columns/spacing/card size/scale)
/// - Overview presentation drag mapping (translation -> progress)
/// - Safari-like overview transform tuning (scale/lift/opacity)
///
/// No SwiftUI/UIKit types are used here; consumers can map outputs to UI as needed.
public enum OverviewPhysicsEngine {

    // MARK: - Layout

    public struct LayoutInput: Sendable, Equatable {
        public var containerWidth: CGFloat
        public var presentationProgress: CGFloat
        public var previousColumns: Int?
        public var policy: OverviewLayoutPolicy

        public init(
            containerWidth: CGFloat,
            presentationProgress: CGFloat,
            previousColumns: Int?,
            policy: OverviewLayoutPolicy
        ) {
            self.containerWidth = containerWidth
            self.presentationProgress = presentationProgress
            self.previousColumns = previousColumns
            self.policy = policy
        }
    }

    public struct LayoutOutput: Sendable, Equatable {
        public var columns: Int
        public var interCardSpacing: CGFloat
        public var cardSize: CGSize
        public var sectionInsets: OverviewLayoutPolicy.Insets
        public var scale: CGFloat

        public init(
            columns: Int,
            interCardSpacing: CGFloat,
            cardSize: CGSize,
            sectionInsets: OverviewLayoutPolicy.Insets,
            scale: CGFloat
        ) {
            self.columns = columns
            self.interCardSpacing = interCardSpacing
            self.cardSize = cardSize
            self.sectionInsets = sectionInsets
            self.scale = scale
        }
    }

    public static func resolveLayout(_ input: LayoutInput) -> LayoutOutput {
        let safeWidth = max(0, input.containerWidth)
        let columns = input.policy.columns(containerWidth: safeWidth, previous: input.previousColumns)
        let spacing = input.policy.resolvedInterCardSpacing(containerWidth: safeWidth)
        let cardSize = input.policy.cardSize(containerWidth: safeWidth, columns: columns, interCardSpacing: spacing)
        let scale = input.policy.scaleCurve.scale(progress: input.presentationProgress)
        return LayoutOutput(
            columns: columns,
            interCardSpacing: spacing,
            cardSize: cardSize,
            sectionInsets: input.policy.sectionInsets,
            scale: scale
        )
    }

    // MARK: - Overview presentation gesture mapping

    public enum TransitionSource: Sendable, Equatable {
        case overlay
        case chrome(isTopChrome: Bool)
    }

    // MARK: - Transition settle decision (pure)

    /// Pure, deterministic transition settle logic for tab overview presentation.
    ///
    /// This machine does **not** animate; it only decides targets and tracks the
    /// current interaction mode so UI can remain interruptible.
    public struct TransitionMachine: Sendable {

        public enum Target: Equatable, Sendable {
            case open
            case closed

            public var progress: CGFloat { self == .open ? 1 : 0 }
            public var isVisible: Bool { self == .open }
        }

        public enum State: Equatable, Sendable {
            case closed
            case open
            case tracking(startProgress: CGFloat)
            case settling(target: Target)
        }

        public struct Configuration: Sendable {
            public var settleThreshold: CGFloat
            public var projectedSettleThreshold: CGFloat

            public init(settleThreshold: CGFloat, projectedSettleThreshold: CGFloat) {
                self.settleThreshold = settleThreshold
                self.projectedSettleThreshold = projectedSettleThreshold
            }
        }

        public private(set) var config: Configuration
        public private(set) var state: State

        public init(
            initial: State = .closed,
            config: Configuration = .init(settleThreshold: 0.50, projectedSettleThreshold: 0.52)
        ) {
            self.state = initial
            self.config = config
        }

        public mutating func setVisible(_ visible: Bool) {
            state = visible ? .open : .closed
        }

        public mutating func beginTracking(currentProgress: CGFloat) {
            state = .tracking(startProgress: clamp01(currentProgress))
        }

        public mutating func settle(to target: Target) {
            state = .settling(target: target)
        }

        /// Deterministic settle decision based on current + projected progress.
        public func decideTarget(currentProgress: CGFloat, projectedProgress: CGFloat) -> Target {
            let current = clamp01(currentProgress)
            let projected = clamp01(projectedProgress)

            if projected >= config.projectedSettleThreshold { return .open }
            if projected <= (1 - config.projectedSettleThreshold) { return .closed }

            return (current >= config.settleThreshold) ? .open : .closed
        }

        private func clamp01(_ x: CGFloat) -> CGFloat {
            min(1, max(0, x))
        }
    }

    public struct DragInput: Sendable, Equatable {
        public var source: TransitionSource
        public var translation: CGFloat
        public var predictedEndTranslation: CGFloat
        public var openDistance: CGFloat
        public var deadZone: CGFloat
        public var currentProgress: CGFloat

        public init(
            source: TransitionSource,
            translation: CGFloat,
            predictedEndTranslation: CGFloat,
            openDistance: CGFloat,
            deadZone: CGFloat,
            currentProgress: CGFloat
        ) {
            self.source = source
            self.translation = translation
            self.predictedEndTranslation = predictedEndTranslation
            self.openDistance = openDistance
            self.deadZone = deadZone
            self.currentProgress = currentProgress
        }
    }

    public struct DragUpdateOutput: Sendable, Equatable {
        public var nextProgress: CGFloat
        public var shouldForceVisible: Bool

        public init(nextProgress: CGFloat, shouldForceVisible: Bool) {
            self.nextProgress = nextProgress
            self.shouldForceVisible = shouldForceVisible
        }
    }

    public struct DragEndOutput: Sendable, Equatable {
        public var projectedProgress: CGFloat

        public init(projectedProgress: CGFloat) {
            self.projectedProgress = projectedProgress
        }
    }

    public static func updateDrag(_ input: DragInput) -> DragUpdateOutput? {
        if abs(input.translation) < input.deadZone {
            return nil
        }

        let distance = max(1, input.openDistance)
        let deltaProgress = dragDeltaProgress(source: input.source, translation: input.translation, distance: distance)
        let next = clamp01(input.currentProgress + deltaProgress)
        return DragUpdateOutput(nextProgress: next, shouldForceVisible: next > 0.001)
    }

    public static func endDrag(_ input: DragInput) -> DragEndOutput {
        let distance = max(1, input.openDistance)
        let projectedDelta = dragDeltaProgress(
            source: input.source,
            translation: input.predictedEndTranslation,
            distance: distance
        )
        let projected = clamp01(input.currentProgress + projectedDelta)
        return DragEndOutput(projectedProgress: projected)
    }

    private static func dragDeltaProgress(source: TransitionSource, translation: CGFloat, distance: CGFloat) -> CGFloat {
        switch source {
        case .overlay:
            return -translation / max(1, distance)
        case .chrome(let isTopChrome):
            let signed = isTopChrome ? translation : -translation
            return signed / max(1, distance)
        }
    }

    // MARK: - Transform tuning

    public struct TransformInput: Sendable, Equatable {
        public var progress: CGFloat
        public var isLandscapeSplit: Bool

        public init(progress: CGFloat, isLandscapeSplit: Bool) {
            self.progress = progress
            self.isLandscapeSplit = isLandscapeSplit
        }
    }

    public struct TransformOutput: Sendable, Equatable {
        public var scale: CGFloat
        public var liftY: CGFloat
        public var opacity: Double

        public init(scale: CGFloat, liftY: CGFloat, opacity: Double) {
            self.scale = scale
            self.liftY = liftY
            self.opacity = opacity
        }
    }

    public static func overviewTransform(_ input: TransformInput) -> TransformOutput {
        let p = clamp01(input.progress)
        let minScale: CGFloat = input.isLandscapeSplit ? 0.90 : 0.86
        let scale = 1 - (1 - minScale) * p
        let lift: CGFloat = input.isLandscapeSplit ? -26 * p : -44 * p
        let opacity: Double = 1 - 0.18 * Double(p)
        return TransformOutput(scale: scale, liftY: lift, opacity: opacity)
    }

    private static func clamp01(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }
}

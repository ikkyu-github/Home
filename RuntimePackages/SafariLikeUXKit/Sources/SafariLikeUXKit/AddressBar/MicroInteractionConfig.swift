import CoreGraphics

/// Single configuration point for address bar micro-interactions.
///
/// This is a pure value type intended to be threaded through UI layers.
public struct MicroInteractionConfig: Sendable, Equatable {

    public enum CaretBlinkPolicy: Sendable, Equatable {
        /// Use system defaults.
        case system
        /// Hide the caret entirely (implemented via `tintColor = .clear`).
        case hidden
    }

    public struct FocusExpandCurve: Sendable, Equatable {
        public var response: Double
        public var dampingFraction: Double
        public var blendDuration: Double

        public init(
            response: Double = 0.28,
            dampingFraction: Double = 0.88,
            blendDuration: Double = 0
        ) {
            self.response = response
            self.dampingFraction = dampingFraction
            self.blendDuration = blendDuration
        }
    }

    public var caretBlinkPolicy: CaretBlinkPolicy
    public var selectionAnimationDuration: Double
    public var focusExpandCurve: FocusExpandCurve
    public var cancelButtonRevealThreshold: CGFloat
    public var scrollCollapseCouplingStrength: CGFloat

    public init(
        caretBlinkPolicy: CaretBlinkPolicy = .system,
        selectionAnimationDuration: Double = 0.12,
        focusExpandCurve: FocusExpandCurve = .init(),
        cancelButtonRevealThreshold: CGFloat = 0.55,
        scrollCollapseCouplingStrength: CGFloat = 0.85
    ) {
        self.caretBlinkPolicy = caretBlinkPolicy
        self.selectionAnimationDuration = selectionAnimationDuration
        self.focusExpandCurve = focusExpandCurve
        self.cancelButtonRevealThreshold = cancelButtonRevealThreshold
        self.scrollCollapseCouplingStrength = scrollCollapseCouplingStrength
    }
}

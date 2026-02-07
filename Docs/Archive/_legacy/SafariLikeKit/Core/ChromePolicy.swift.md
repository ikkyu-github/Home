import Foundation
import CoreGraphics

/// Source of truth for Chrome UI policies used by SafariLikeKit.
///
/// Threading: ChromePolicy is main-actor oriented; create and
/// use instances on the main actor.
@MainActor
public struct ChromePolicy {
    public struct KeyboardLiftPolicy {
        public let shouldLift: Bool
        public let liftAmount: CGFloat
        
        public init(shouldLift: Bool, liftAmount: CGFloat) {
            self.shouldLift = shouldLift
            self.liftAmount = liftAmount
        }
    }
    public struct ChromeHeightPolicy {
        public let minHeight: CGFloat
        public let maxHeight: CGFloat
        public var currentHeight: CGFloat
        
        public init(minHeight: CGFloat, maxHeight: CGFloat, currentHeight: CGFloat) {
            self.minHeight = minHeight
            self.maxHeight = maxHeight
            self.currentHeight = currentHeight
        }
    }
    public struct AnimationRule {
        public enum Curve: String, Sendable {
            case standardEaseInOut
        }

        public let curve: Curve
        public let duration: TimeInterval
        
        public init(curve: Curve, duration: TimeInterval) {
            self.curve = curve
            self.duration = duration
        }
    }

    public let keyboardLiftPolicy: KeyboardLiftPolicy
    public let chromeHeightPolicy: ChromeHeightPolicy
    public let animationRule: AnimationRule

    /// Initialize ChromePolicy with all components.
    ///
    /// - Parameters:
    ///   - keyboardLiftPolicy: Policy for keyboard lift behavior
    ///   - chromeHeightPolicy: Policy for chrome height management
    ///   - animationRule: Animation rules for chrome transitions
    public init(
        keyboardLiftPolicy: KeyboardLiftPolicy,
        chromeHeightPolicy: ChromeHeightPolicy,
        animationRule: AnimationRule
    ) {
        self.keyboardLiftPolicy = keyboardLiftPolicy
        self.chromeHeightPolicy = chromeHeightPolicy
        self.animationRule = animationRule
    }

    /// Create a default policy for a given horizontal compactness.
    ///
    /// Threading: Call on the main actor.
    public static func defaultPolicy(isCompact: Bool) -> ChromePolicy {
        // Example values, adjust as needed
        let minHeight: CGFloat = isCompact ? 44 : 64
        let maxHeight: CGFloat = isCompact ? 88 : 128
        let currentHeight: CGFloat = minHeight
        let keyboardLift = KeyboardLiftPolicy(shouldLift: true, liftAmount: isCompact ? 44 : 64)
        let chromeHeight = ChromeHeightPolicy(minHeight: minHeight, maxHeight: maxHeight, currentHeight: currentHeight)
        let animation = AnimationRule(
            curve: .standardEaseInOut,
            duration: 0.25
        )
        return ChromePolicy(
            keyboardLiftPolicy: keyboardLift,
            chromeHeightPolicy: chromeHeight,
            animationRule: animation
        )
    }
}

import SwiftUI

/// Observes the *animating* (presentation) value of a CGFloat.
///
/// Useful for making transitions interruptible by capturing the in-flight
/// progress during a SwiftUI animation.
public struct AnimatableCGFloatObserver: AnimatableModifier {
    public var animatableData: CGFloat {
        didSet { notify(animatableData) }
    }

    private let onChange: (CGFloat) -> Void

    public init(value: CGFloat, onChange: @escaping (CGFloat) -> Void) {
        self.animatableData = value
        self.onChange = onChange
    }

    public func body(content: Content) -> some View {
        content
    }

    private func notify(_ value: CGFloat) {
        Task { @MainActor in
            // Avoid mutating SwiftUI state during an in-flight animation tick.
            await Task.yield()
            onChange(value)
        }
    }
}

public extension View {
    func observeAnimatableCGFloat(_ value: CGFloat, onChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(AnimatableCGFloatObserver(value: value, onChange: onChange))
    }
}

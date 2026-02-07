import SwiftUI
import UIKit
import SafariLikeCoreKit
/// Press interaction tuned to feel Safari-like:
/// - press: scale 0.98
/// - release: spring back
struct SafariPressableScaleButtonStyle: ButtonStyle {
    let baseScale: CGFloat
    init(baseScale: CGFloat = 1) {
        self.baseScale = baseScale
    }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(baseScale * (configuration.isPressed ? 0.98 : 1))
            .animation(SafariMotion.spring, value: configuration.isPressed)
    }
}
struct SafariHoverHighlight: ViewModifier {
    let cornerRadius: CGFloat
    let opacity: CGFloat
    @State private var isHovered: Bool = false
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(isHovered ? opacity : 0))
                    .allowsHitTesting(false)
            )
            .onHover { hovering in
                // Keep hover feel subtle and quick; spring feels too "bouncy" for pointer.
                withAnimation(.linear(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .hoverEffect(.highlight)
    }
}
/// Calls `completion` when an implicit SwiftUI animation finishes for the given `value`.
///
/// This avoids hard-coded delays (e.g. `asyncAfter`) that are brittle across devices.
private struct AnimationCompletionObserver<Value: VectorArithmetic>: AnimatableModifier {
    private let targetValue: Value
    private let completion: () -> Void
    var animatableData: Value {
        didSet { notifyIfFinished() }
    }
    init(for value: Value, completion: @escaping () -> Void) {
        self.targetValue = value
        self.completion = completion
        self.animatableData = value
    }
    func body(content: Content) -> some View {
        content
    }
    private func notifyIfFinished() {
        guard animatableData == targetValue else { return }
        Task { @MainActor in
            completion()
        }
    }
}
private struct CGSizeAnimationCompletionObserver: AnimatableModifier {
    private let targetValue: CGSize
    private let completion: () -> Void
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        didSet { notifyIfFinished() }
    }
    init(for value: CGSize, completion: @escaping () -> Void) {
        self.targetValue = value
        self.completion = completion
        self.animatableData = AnimatablePair(value.width, value.height)
    }
    func body(content: Content) -> some View {
        content
    }
    private func notifyIfFinished() {
        guard animatableData.first == targetValue.width,
              animatableData.second == targetValue.height
        else { return }
        Task { @MainActor in
            completion()
        }
    }
}
enum SafariScrollPhysics {
    case tabStrip
    case overview
}
private struct ScrollViewTuner: UIViewRepresentable {
    let configure: (UIScrollView) -> Void
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        Task { @MainActor in
            // SwiftUI may not have fully assembled the UIKit subtree during this update pass.
            // Yield once so we can reliably find the hosting UIScrollView.
            await Task.yield()
            guard let scrollView = Self.findScrollView(from: uiView) else { return }
            configure(scrollView)
        }
    }
    private static func findScrollView(from view: UIView) -> UIScrollView? {
        // Walk up the view tree; SwiftUI nests UIScrollView several levels above.
        var current: UIView? = view
        for _ in 0..<32 {
            if let scroll = current as? UIScrollView { return scroll }
            if let current {
                if let found = findScrollViewInSubviews(of: current) { return found }
            }
            current = current?.superview
        }
        return nil
    }
    private static func findScrollViewInSubviews(of view: UIView) -> UIScrollView? {
        for sub in view.subviews {
            if let scroll = sub as? UIScrollView { return scroll }
            if let found = findScrollViewInSubviews(of: sub) { return found }
        }
        return nil
    }
}
extension View {
    func safariHoverHighlight(cornerRadius: CGFloat, opacity: CGFloat = 0.06) -> some View {
        modifier(SafariHoverHighlight(cornerRadius: cornerRadius, opacity: opacity))
    }
    func onAnimationCompleted(for value: CGFloat, completion: @escaping () -> Void) -> some View {
        modifier(AnimationCompletionObserver(for: value, completion: completion))
    }
    func onAnimationCompleted(for value: CGSize, completion: @escaping () -> Void) -> some View {
        modifier(CGSizeAnimationCompletionObserver(for: value, completion: completion))
    }
    func safariScrollPhysics(_ physics: SafariScrollPhysics) -> some View {
        background(
            ScrollViewTuner { scroll in
                switch physics {
                case .tabStrip:
                    scroll.decelerationRate = .fast
                    scroll.bounces = false
                    scroll.alwaysBounceHorizontal = false
                    scroll.alwaysBounceVertical = false
                case .overview:
                    // "Light" rubber band: keep bounces, avoid overly aggressive deceleration.
                    scroll.decelerationRate = .normal
                    scroll.bounces = true
                }
            }
        )
    }
}

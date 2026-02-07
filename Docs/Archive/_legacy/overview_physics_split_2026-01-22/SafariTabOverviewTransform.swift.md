import SwiftUI

public struct SafariTabOverviewTransform: ViewModifier {
    public var progress: CGFloat
    public var isLandscapeSplit: Bool

    public init(progress: CGFloat, isLandscapeSplit: Bool) {
        self.progress = progress
        self.isLandscapeSplit = isLandscapeSplit
    }

    public func body(content: Content) -> some View {
        let p = max(0, min(1, progress))
        let minScale: CGFloat = isLandscapeSplit ? 0.90 : 0.86
        let scale = 1 - (1 - minScale) * p
        let lift: CGFloat = isLandscapeSplit ? -26 * p : -44 * p
        let opacity: Double = 1 - 0.18 * Double(p)
        return content
            .scaleEffect(scale, anchor: .center)
            .offset(y: lift)
            .opacity(opacity)
    }
}

public extension View {
    func safariTabOverviewTransform(progress: CGFloat, isLandscapeSplit: Bool) -> some View {
        self.modifier(SafariTabOverviewTransform(progress: progress, isLandscapeSplit: isLandscapeSplit))
    }
}

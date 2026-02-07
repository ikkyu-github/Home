import SwiftUI

public struct SafariTabOverviewTransform: ViewModifier {
    public var progress: CGFloat
    public var isLandscapeSplit: Bool

    public init(progress: CGFloat, isLandscapeSplit: Bool) {
        self.progress = progress
        self.isLandscapeSplit = isLandscapeSplit
    }

    public func body(content: Content) -> some View {
        let out = OverviewPhysicsEngine.overviewTransform(
            .init(progress: progress, isLandscapeSplit: isLandscapeSplit)
        )
        return content
            .scaleEffect(out.scale, anchor: .center)
            .offset(y: out.liftY)
            .opacity(out.opacity)
    }
}

public extension View {
    func safariTabOverviewTransform(progress: CGFloat, isLandscapeSplit: Bool) -> some View {
        self.modifier(SafariTabOverviewTransform(progress: progress, isLandscapeSplit: isLandscapeSplit))
    }
}

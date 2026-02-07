import CoreGraphics

public struct SplitPhysics: Sendable, Equatable {
    public var minRatio: CGFloat
    public var maxRatio: CGFloat
    public var snapPoints: [CGFloat]

    public init(minRatio: CGFloat, maxRatio: CGFloat, snapPoints: [CGFloat]) {
        self.minRatio = minRatio
        self.maxRatio = maxRatio
        self.snapPoints = snapPoints
    }

    public static let safariIPad: SplitPhysics = .init(
        minRatio: 0.20,
        maxRatio: 0.60,
        snapPoints: [0.25, 0.33, 0.50]
    )

    public func clamp(_ ratio: CGFloat) -> CGFloat {
        min(maxRatio, max(minRatio, ratio))
    }

    public func snappedTarget(current: CGFloat, velocityX: CGFloat) -> CGFloat {
        let v = velocityX
        let clamped = clamp(current)

        // If the user flicks, bias to the next snap point in the flick direction.
        if abs(v) > 900, snapPoints.isEmpty == false {
            let sorted = snapPoints.sorted()
            if v > 0 {
                // expanding: snap up
                return sorted.first(where: { $0 > clamped }) ?? sorted.last ?? clamped
            } else {
                // shrinking: snap down
                return sorted.reversed().first(where: { $0 < clamped }) ?? sorted.first ?? clamped
            }
        }

        // Otherwise, snap to the nearest point.
        let points = (snapPoints + [clamped]).map { clamp($0) }
        return points.min(by: { abs($0 - clamped) < abs($1 - clamped) }) ?? clamped
    }
}

import Foundation
import CoreGraphics

public enum PhysicsTuning {
    public static let springResponse: Double = 0.28
    public static let dampingFraction: Double = 0.86

    public static let openVelocityThreshold: CGFloat = 900
    public static let closeVelocityThreshold: CGFloat = -900

    public static let rubberBandFactor: CGFloat = 0.28
    public static let gestureDeadZone: CGFloat = 8

    public static let overviewSnapPoints: [CGFloat] = [0, 320]

    public static func projectedOffset(initial: CGFloat, velocity: CGFloat, dt: CGFloat = 0.18) -> CGFloat {
        initial + velocity * dt
    }

    public static func nearestSnapPoint(offset: CGFloat) -> CGFloat {
        overviewSnapPoints.min(by: { abs($0 - offset) < abs($1 - offset) }) ?? 0
    }

    public static func shouldOpenOverview(velocity: CGFloat, offset: CGFloat) -> Bool {
        if velocity > openVelocityThreshold { return true }
        return offset > 140
    }

    public static func shouldCloseOverview(velocity: CGFloat, offset: CGFloat) -> Bool {
        if velocity < closeVelocityThreshold { return true }
        return offset < 90
    }

    public static func rubberBand(_ value: CGFloat, limit: CGFloat) -> CGFloat {
        if value < 0 {
            return -rubberBandAmount(-value, limit: limit)
        }
        if value > limit {
            return limit + rubberBandAmount(value - limit, limit: limit)
        }
        return value
    }

    private static func rubberBandAmount(_ x: CGFloat, limit: CGFloat) -> CGFloat {
        let c: CGFloat = rubberBandFactor
        return (1 - (1 / ((x * c / limit) + 1))) * limit
    }
}

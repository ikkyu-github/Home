import Foundation

/// Safari-grade discard levels for tab runtime resources.
///
/// Levels are ordered: higher means more aggressive resource release.
public enum TabDiscardLevel: Int, Codable, Sendable, Comparable {
    case keepAttached = 0
    case detachKeepSnapshot = 1
    case freezeCold = 2
    case discardKeepToken = 3

    public static func < (lhs: TabDiscardLevel, rhs: TabDiscardLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

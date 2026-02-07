import CoreGraphics
import SafariLikeCoreKit
/// UI-only policy for deciding whether split (two-pane) UI should be presented.
///
/// This intentionally avoids device-idiom branching so iPhone/iPad behavior is consistent
/// for the same available width.
public struct SplitViewPolicy {
    public static func isSplitEnabled(for width: CGFloat) -> Bool {
        // Allow split on iPhone-sized widths (e.g. 390pt).
        width >= 390
    }
}

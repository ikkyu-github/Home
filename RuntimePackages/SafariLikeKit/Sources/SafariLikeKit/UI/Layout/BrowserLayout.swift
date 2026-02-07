import Foundation
import SafariLikeCoreKit
/// High-level container layout mode for the browser UI.
///
/// This is intentionally small and stable: it answers only “do we present one pane or two panes?”.
public enum BrowserLayout: String, Codable, Equatable {
    case singlePane
    case splitPane
}
public enum BrowserOrientation: String, Codable, Equatable {
    case portrait
    case landscape
}
/// User-facing preference for layout behavior.
///
/// The resolver will still apply device/orientation gating for `.preferSplitWhenPossible`.
public enum BrowserLayoutUserPreference: String, Codable, Equatable {
    /// Choose the most appropriate layout for the current device + orientation.
    case automatic
    /// Always prefer a single pane.
    case singlePaneOnly
    /// Prefer split pane when the device/orientation rules allow it.
    case preferSplitWhenPossible
}

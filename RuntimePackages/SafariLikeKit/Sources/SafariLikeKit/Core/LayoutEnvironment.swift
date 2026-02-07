import Foundation
import SafariLikeCoreKit
/// High-level layout mode used to drive runtime decisions (render budget, attach/detach, pool priority)
/// without branching on device idiom.
public enum LayoutEnvironment: String, Codable, Equatable, Sendable {
    /// A single browser content pane is visible (Safari iPhone portrait and iPad compact).
    case compactSinglePane
    /// Two browser content panes can be visible in one scene (Safari iPad split view).
    case splitPane
    /// Multiple scenes/windows are active; runtime should behave conservatively per-window.
    case multiWindow
}

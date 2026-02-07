import Foundation
import SafariLikeCoreKit
/// High-level actions for Split Browser coordination.
/// Wraps existing BrowserAction to avoid duplicating logic.
enum SplitBrowserAction {
    case browser(BrowserAction)
    // Convenience UI actions
    case toggleSidebar
    case showTabOverview(Bool)
    case toggleCompanion
    case setSplitEnabled(Bool)
}

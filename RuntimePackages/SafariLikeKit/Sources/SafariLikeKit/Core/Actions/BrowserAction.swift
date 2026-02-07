import Foundation
import SafariLikeCoreKit
/// Action-based navigation/events for the browser.
/// This keeps Views declarative and moves imperative behavior into the reducer (ViewModel/Store).
enum BrowserAction: Sendable {
    // Tabs
    case newTab(urlString: String? = nil, inBackground: Bool = false)
    case closeTab(UUID)
    case selectTab(UUID)
    case moveTab(from: Int, to: Int)
    // Navigation
    case openURLString(String)
    /// Like `openURLString`, but forces a navigation even if the URL matches current state.
    case openURLStringForce(String)
    case goBack
    case goForward
    case reload
    case stopLoading
    case shareCurrentPage
    /// Forces a WebView attach attempt for the currently active tab.
    /// Used to recover from stuck "Attaching WebView" / timeout states.
    case forceAttachWebView
    // Companion (Related / sidebar)
    case openCompanion(CompanionContent)
    case closeCompanion
    case toggleCompanion
    /// First-class Related toggle (Safari-like): toggles only the Related visibility state.
    case toggleRelated
    /// Sets Related visibility explicitly (used by drag-to-close / scrim tap).
    case setRelatedVisible(Bool)
    // UI modes
    case showTabOverview(Bool)
    case setSplitViewEnabled(Bool)
}
/// What the companion pane is showing.
enum CompanionContent: Hashable, Sendable {
    case related
    case bookmarks
    case history
    case settings
}

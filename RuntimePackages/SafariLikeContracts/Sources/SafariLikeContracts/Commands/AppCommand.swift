import Foundation

/// UI command intent (typically triggered by keyboard shortcuts or menu items).
///
/// This type is intentionally UI-framework-neutral so it can be routed and tested
/// without importing SwiftUI/UIKit.
public enum AppCommand: Codable, Sendable, Hashable {
    case focusAddressBar
    case newTab
    case close
    case reopenLastClosedTab

    case reload
    case goBack
    case goForward

    case showFindOnPage
    case showSettings

    /// Select a tab by the number row semantics (Safari-style).
    ///
    /// - 1 selects the first tab.
    /// - 9 selects the last tab.
    case selectTabByNumber(Int)

    case selectNextTab
    case selectPreviousTab

    case toggleTabOverview
}

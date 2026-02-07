import Foundation

/// UI-facing events for driving Safari-like chrome behavior.
///
/// Intentionally UI-safe (no UIKit/CoreGraphics/WebKit types).
public enum ChromeEvent: Sendable, Equatable {
    case focusChanged(Bool)
    case scroll(y: Double, velocityY: Double)
    case overviewToggled(Bool)
    case commit
    case cancel
}

/// Minimal, UI-facing view state for rendering chrome.
public struct ChromeViewState: Sendable, Equatable {
    public var isCollapsed: Bool
    public var isEditing: Bool
    public var isInOverview: Bool
    public var isOmniboxOverlayVisible: Bool
    public var isAddressFocused: Bool

    public init(
        isCollapsed: Bool,
        isEditing: Bool,
        isInOverview: Bool,
        isOmniboxOverlayVisible: Bool,
        isAddressFocused: Bool
    ) {
        self.isCollapsed = isCollapsed
        self.isEditing = isEditing
        self.isInOverview = isInOverview
        self.isOmniboxOverlayVisible = isOmniboxOverlayVisible
        self.isAddressFocused = isAddressFocused
    }

    public static let expandedDefault = ChromeViewState(
        isCollapsed: false,
        isEditing: false,
        isInOverview: false,
        isOmniboxOverlayVisible: false,
        isAddressFocused: false
    )
}

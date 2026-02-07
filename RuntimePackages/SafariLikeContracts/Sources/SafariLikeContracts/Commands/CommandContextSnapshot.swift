import Foundation

/// Snapshot of a scene's UI/runtime state used for deterministic command routing.
///
/// Notes:
/// - This is intentionally a "dumb" value type (no references to WebKit/SwiftUI/UIKit).
/// - Any IDs must be scene-local identifiers (e.g., tab IDs), never cross-scene objects.
public struct CommandContextSnapshot: Codable, Sendable, Hashable {
    public var tabCount: Int

    /// The active/selected tab in the scene (when not in tab overview).
    public var activeTabID: UUID?

    /// The highlighted/selected tab in the tab overview UI (if visible).
    public var tabOverviewSelectedTabID: UUID?

    public var isTabOverviewVisible: Bool
    public var isAddressBarFocused: Bool
    public var isFindOnPagePresented: Bool
    public var isSettingsPresented: Bool
    public var isPrivateBrowsingEnabled: Bool

    /// True if an undo-close operation can restore a recently closed tab.
    public var hasRecentlyClosedTabs: Bool

    public init(
        tabCount: Int,
        activeTabID: UUID?,
        tabOverviewSelectedTabID: UUID?,
        isTabOverviewVisible: Bool,
        isAddressBarFocused: Bool,
        isFindOnPagePresented: Bool,
        isSettingsPresented: Bool,
        isPrivateBrowsingEnabled: Bool,
        hasRecentlyClosedTabs: Bool
    ) {
        self.tabCount = tabCount
        self.activeTabID = activeTabID
        self.tabOverviewSelectedTabID = tabOverviewSelectedTabID
        self.isTabOverviewVisible = isTabOverviewVisible
        self.isAddressBarFocused = isAddressBarFocused
        self.isFindOnPagePresented = isFindOnPagePresented
        self.isSettingsPresented = isSettingsPresented
        self.isPrivateBrowsingEnabled = isPrivateBrowsingEnabled
        self.hasRecentlyClosedTabs = hasRecentlyClosedTabs
    }
}

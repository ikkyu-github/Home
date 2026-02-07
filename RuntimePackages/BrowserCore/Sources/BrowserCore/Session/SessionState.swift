import Foundation

/// Persistable session state for multi-window + split-pane browsing.
///
/// - Important: Keep this file UIKit/SwiftUI-free.
public struct SessionState: Codable, Sendable {
    public var windows: [WindowState]

    /// Tab groups for this session window (best-effort).
    public var tabGroups: [BrowserTabGroup]
    public var selectedTabGroupID: UUID?

    public init(
        windows: [WindowState],
        tabGroups: [BrowserTabGroup] = [],
        selectedTabGroupID: UUID? = nil
    ) {
        self.windows = windows
        self.tabGroups = tabGroups
        self.selectedTabGroupID = selectedTabGroupID
    }
}

public struct WindowState: Codable, Sendable {
    public var id: UUID

    /// The tab the user considers "selected" in this window.
    ///
    /// This can be `nil` if the window has no tabs yet.
    public var selectedTabID: UUID?

    /// Supports split view (up to 2 panes).
    public var panes: [PaneState]

    public init(id: UUID = UUID(), selectedTabID: UUID?, panes: [PaneState]) {
        self.id = id
        self.selectedTabID = selectedTabID
        self.panes = panes
    }
}

public struct PaneState: Codable, Sendable {
    public var activeTabID: UUID?
    public var tabOrder: [TabState]

    public init(activeTabID: UUID?, tabOrder: [TabState]) {
        self.activeTabID = activeTabID
        self.tabOrder = tabOrder
    }
}

public struct TabState: Codable, Sendable {
    public enum LifecycleState: String, Codable, Sendable {
        case active
        case frozen
        case evicted
    }

    public var tabID: UUID
    public var url: URL
    public var title: String?

    /// Optional lightweight history summary.
    public var backForwardListSummary: BackForwardListSummary?

    /// Optional last rendered snapshot ID for fast restore.
    public var lastSnapshotID: UUID?

    public var lifecycleState: LifecycleState

    public init(
        tabID: UUID = UUID(),
        url: URL,
        title: String? = nil,
        backForwardListSummary: BackForwardListSummary? = nil,
        lastSnapshotID: UUID? = nil,
        lifecycleState: LifecycleState
    ) {
        self.tabID = tabID
        self.url = url
        self.title = title
        self.backForwardListSummary = backForwardListSummary
        self.lastSnapshotID = lastSnapshotID
        self.lifecycleState = lifecycleState
    }
}

public struct BackForwardListSummary: Codable, Sendable, Equatable, Hashable {
    public struct Item: Codable, Sendable, Equatable, Hashable {
        public var url: URL
        public var title: String?

        public init(url: URL, title: String? = nil) {
            self.url = url
            self.title = title
        }
    }

    public var back: [Item]
    public var current: Item?
    public var forward: [Item]

    public init(back: [Item] = [], current: Item? = nil, forward: [Item] = []) {
        self.back = back
        self.current = current
        self.forward = forward
    }
}

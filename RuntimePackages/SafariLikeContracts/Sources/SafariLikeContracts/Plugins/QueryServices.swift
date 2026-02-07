import Foundation

/// Read-only query services for the Core → Plugin boundary.
///
/// These protocols intentionally expose only async read APIs and must not
/// provide any mutating operations. Concrete implementations live in runtime
/// layers and may consult Core-owned state/stores.

/// Read-only access to the current window's tabs (requires `.tabObservation`).
public protocol TabQueryService: AnyObject, Sendable {
    func openTabs() async throws -> [PluginTabSnapshot]
}

/// Read-only history access (requires `.historyRead`).
public protocol HistoryQueryService: AnyObject, Sendable {
    func recentHistory(limit: Int) async throws -> [PluginHistoryItem]
}

/// Read-only bookmarks access (requires `.bookmarksRead`).
public protocol BookmarksQueryService: AnyObject, Sendable {
    func bookmarks() async throws -> [PluginBookmarkItem]
}

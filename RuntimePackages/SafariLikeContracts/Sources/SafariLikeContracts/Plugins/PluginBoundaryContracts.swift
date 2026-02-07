import Foundation

/// Read-only navigation APIs (requires `.navigationRead`).
///
/// These protocols are deliberately minimal so plugin implementations can
/// compile against SafariLikeContracts without any runtime/WebKit/UI imports.
public protocol NavigationReadContext {
    var windowID: String { get }
    var tabID: String { get }

    func hasCapability(_ capability: PluginCapability) -> Bool
}

// MARK: - Library / session read boundaries

/// Minimal tab snapshot exposed to plugins.
///
/// This intentionally does not expose any mutable browser objects.
public struct PluginTabSnapshot: Codable, Hashable, Sendable {
    public let id: String
    public let title: String?
    public let urlString: String?
    public let isActive: Bool

    public init(id: String, title: String?, urlString: String?, isActive: Bool) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.isActive = isActive
    }
}

/// Minimal history snapshot exposed to plugins.
public struct PluginHistoryItem: Codable, Hashable, Sendable {
    public let urlString: String
    public let title: String?
    public let lastVisitedAt: Date?

    public init(urlString: String, title: String?, lastVisitedAt: Date?) {
        self.urlString = urlString
        self.title = title
        self.lastVisitedAt = lastVisitedAt
    }
}

/// Minimal bookmark snapshot exposed to plugins.
public struct PluginBookmarkItem: Codable, Hashable, Sendable {
    public let urlString: String
    public let title: String?

    public init(urlString: String, title: String?) {
        self.urlString = urlString
        self.title = title
    }
}

/// Read-only access to window tabs (requires `.tabObservation`).
public protocol TabObservationContext {
    func openTabs() async throws -> [PluginTabSnapshot]
}

/// Read-only history access (requires `.historyRead`).
public protocol HistoryReadContext {
    func recentHistory(limit: Int) async throws -> [PluginHistoryItem]
}

/// Read-only bookmarks access (requires `.bookmarksRead`).
public protocol BookmarksReadContext {
    func bookmarks() async throws -> [PluginBookmarkItem]
}

/// Interception marker (requires `.navigationIntercept`).
public protocol NavigationInterceptContext {}

/// Content injection marker (requires `.contentScripts`).
public protocol ContentInjectContext {}

/// Composite browser plugin context used by advanced plugins.
public protocol BrowserPluginContext: NavigationReadContext, NavigationInterceptContext, ContentInjectContext, TabObservationContext, HistoryReadContext, BookmarksReadContext {}

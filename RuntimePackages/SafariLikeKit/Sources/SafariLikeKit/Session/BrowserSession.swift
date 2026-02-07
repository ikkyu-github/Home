import Foundation
import SafariLikeCoreKit
public struct TabSession: Sendable, Equatable {
    public var id: UUID
    public var url: URL?
    public var title: String?
    public var scrollOffset: Double
    public var isPinned: Bool
    public var isPrivate: Bool
    public init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String? = nil,
        scrollOffset: Double = 0,
        isPinned: Bool = false,
        isPrivate: Bool = false
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.scrollOffset = scrollOffset
        self.isPinned = isPinned
        self.isPrivate = isPrivate
    }
}
/// In-memory representation of a browser session.
///
/// This model is intentionally WebKit-free (no WKWebView references).
public struct BrowserSession: Sendable, Equatable {
    public enum SplitState: String, Sendable, Equatable {
        case single
        case dual
    }
    public var sessionID: UUID
    public var windowID: UUID
    public var tabs: [TabSession]
    public var activeTabID: UUID?
    public var splitState: SplitState
    public var timestamp: Date
    public init(
        sessionID: UUID = UUID(),
        windowID: UUID,
        tabs: [TabSession] = [],
        activeTabID: UUID? = nil,
        splitState: SplitState = .single,
        timestamp: Date = Date()
    ) {
        self.sessionID = sessionID
        self.windowID = windowID
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.splitState = splitState
        self.timestamp = timestamp
    }
}

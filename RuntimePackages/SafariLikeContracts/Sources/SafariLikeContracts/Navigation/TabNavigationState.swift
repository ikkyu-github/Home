import Foundation

/// Durable per-tab navigation state independent of WebKit's back/forward list.
///
/// This is intended to be persisted for regular browsing and kept in-memory only
/// for private browsing.
public struct TabNavigationState: Codable, Sendable, Equatable {

    public struct Cursor: Codable, Sendable, Equatable {
        public var index: Int
        public init(index: Int) { self.index = index }
    }

    /// Non-persisted in-flight intent used to reconcile a future WebKit commit
    /// with a domain navigation request (e.g. back/forward after eviction).
    public enum PendingIntent: Sendable, Equatable {
        case goToIndex(Int)
        case loadURLString(String)
        case replaceWithURLString(String)
    }

    public var entries: [NavigationEntry]
    public var cursor: Cursor?

    /// Not encoded/decoded on purpose.
    public var pending: PendingIntent?

    private enum CodingKeys: String, CodingKey {
        case entries
        case cursor
    }

    public init(entries: [NavigationEntry] = [], cursor: Cursor? = nil, pending: PendingIntent? = nil) {
        self.entries = entries
        self.cursor = cursor
        self.pending = pending
    }
}

public extension TabNavigationState {
    var canGoBack: Bool {
        guard let cursor else { return false }
        return cursor.index > 0 && entries.indices.contains(cursor.index)
    }

    var canGoForward: Bool {
        guard let cursor else { return false }
        return (cursor.index + 1) < entries.count && entries.indices.contains(cursor.index)
    }

    var currentEntry: NavigationEntry? {
        guard let cursor, entries.indices.contains(cursor.index) else { return nil }
        return entries[cursor.index]
    }

    var backCount: Int {
        guard let cursor, entries.indices.contains(cursor.index) else { return 0 }
        return cursor.index
    }

    var forwardCount: Int {
        guard let cursor, entries.indices.contains(cursor.index) else { return 0 }
        return max(0, (entries.count - 1) - cursor.index)
    }

    func entry(at index: Int) -> NavigationEntry? {
        guard entries.indices.contains(index) else { return nil }
        return entries[index]
    }
}

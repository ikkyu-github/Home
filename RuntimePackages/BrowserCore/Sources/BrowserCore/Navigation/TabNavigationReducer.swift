import Foundation
import SafariLikeContracts

public enum TabNavigationCommitKind: String, Codable, Sendable, Equatable {
    case normal
    case redirect
}

public struct TabNavigationCommitContext: Codable, Sendable, Equatable {
    public var urlString: String
    public var title: String?
    public var kind: TabNavigationCommitKind
    public var redirectDepth: Int

    public init(
        urlString: String,
        title: String? = nil,
        kind: TabNavigationCommitKind = .normal,
        redirectDepth: Int = 0
    ) {
        self.urlString = urlString
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = (trimmed?.isEmpty ?? true) ? nil : trimmed
        self.kind = kind
        self.redirectDepth = redirectDepth
    }
}

public enum TabNavigationEvent: Sendable, Equatable {
    case userRequestedGoToIndex(Int)
    case userRequestedLoadURLString(String)
    case userRequestedReplaceWithURLString(String)
    case webKitDidCommit(TabNavigationCommitContext)
}

public enum TabNavigationReducer {
    public static let defaultMaxEntries: Int = 120

    public static func reduce(
        _ state: TabNavigationState,
        event: TabNavigationEvent,
        maxEntries: Int = defaultMaxEntries
    ) -> TabNavigationState {
        var next = state

        switch event {
        case .userRequestedGoToIndex(let index):
            next.pending = .goToIndex(index)

        case .userRequestedLoadURLString(let urlString):
            next.pending = .loadURLString(urlString)

        case .userRequestedReplaceWithURLString(let urlString):
            next.pending = .replaceWithURLString(urlString)

        case .webKitDidCommit(let commit):
            next = applyCommit(next, commit: commit, maxEntries: maxEntries)

        @unknown default:
            assertionFailure("Unhandled TabNavigationEvent: \(event)")
            return next
        }

        return next
    }

    private static func applyCommit(
        _ state: TabNavigationState,
        commit: TabNavigationCommitContext,
        maxEntries: Int
    ) -> TabNavigationState {
        var next = state
        let pendingIntent = next.pending

        let committedEntry = NavigationEntry(urlString: commit.urlString, title: commit.title)

        // If we have a pending intent to go to a specific existing entry, prefer moving the cursor
        // without rewriting history. This is the key for back/forward correctness after eviction.
        if let pendingIntent {
            switch pendingIntent {
            case .goToIndex(let targetIndex):
                if let expected = next.entry(at: targetIndex), expected.urlString == commit.urlString {
                    next.cursor = .init(index: targetIndex)
                    next.pending = nil
                    return next
                }

            case .loadURLString(let expectedURL):
                if expectedURL == commit.urlString {
                    // Treat as a new navigation commit.
                    break
                }

            case .replaceWithURLString(let expectedURL):
                if expectedURL == commit.urlString {
                    // Replace current if possible, else append.
                    next = replaceOrAppend(next, entry: committedEntry, maxEntries: maxEntries)
                    next.pending = nil
                    return next
                }

            @unknown default:
                assertionFailure("Unhandled pending intent: \(String(describing: pendingIntent))")
                break
            }
        }

        // Redirects should not create additional history entries: Safari-like behavior is to
        // collapse the redirect chain into the currently visible entry when possible.
        if commit.kind == .redirect || commit.redirectDepth > 0 {
            next = replaceOrAppend(next, entry: committedEntry, maxEntries: maxEntries)
            next.pending = nil
            return next
        }

        // Normal navigation: append and truncate forward list.
        next = appendNew(next, entry: committedEntry, maxEntries: maxEntries)
        next.pending = nil
        return next
    }

    private static func replaceOrAppend(
        _ state: TabNavigationState,
        entry: NavigationEntry,
        maxEntries: Int
    ) -> TabNavigationState {
        var next = state
        if let cursor = next.cursor, next.entries.indices.contains(cursor.index) {
            next.entries[cursor.index] = entry
            return next
        }
        return appendNew(next, entry: entry, maxEntries: maxEntries)
    }

    private static func appendNew(
        _ state: TabNavigationState,
        entry: NavigationEntry,
        maxEntries: Int
    ) -> TabNavigationState {
        var next = state

        // If we have a cursor, drop any forward entries (new navigation breaks the forward stack).
        if let cursor = next.cursor, next.entries.indices.contains(cursor.index) {
            let keepCount = cursor.index + 1
            if keepCount < next.entries.count {
                next.entries = Array(next.entries.prefix(keepCount))
            }
        }

        next.entries.append(entry)
        next.cursor = .init(index: next.entries.count - 1)

        // Bound history length.
        if next.entries.count > maxEntries {
            let overflow = next.entries.count - maxEntries
            next.entries.removeFirst(overflow)
            if let cursor = next.cursor {
                next.cursor = .init(index: max(0, cursor.index - overflow))
            }
        }

        return next
    }
}

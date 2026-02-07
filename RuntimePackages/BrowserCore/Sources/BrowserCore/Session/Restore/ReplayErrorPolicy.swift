import Foundation

public enum ReplayErrorPolicy: Sendable {
    /// Drop events that reference missing entities (tabs/windows/panes).
    case dropInvalidEvent

    /// When an event references a missing tabID, create an about:blank placeholder tab with that same ID.
    case createPlaceholderTab
}

public struct ReplayOrderingPolicy: Sendable {
    public enum Mode: Sendable {
        /// Sort by `(createdAt, eventID)` for deterministic replay.
        case sortByDeterministicKey

        /// Trust input order; still records diagnostics if out-of-order is detected.
        case trustInputOrder
    }

    public var mode: Mode

    public init(mode: Mode = .sortByDeterministicKey) {
        self.mode = mode
    }
}

public struct SessionReplayPolicy: Sendable {
    public var ordering: ReplayOrderingPolicy
    public var errorPolicy: ReplayErrorPolicy

    public init(ordering: ReplayOrderingPolicy = ReplayOrderingPolicy(), errorPolicy: ReplayErrorPolicy = .createPlaceholderTab) {
        self.ordering = ordering
        self.errorPolicy = errorPolicy
    }
}

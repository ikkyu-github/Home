import Foundation

/// Minimal information required to restore a discarded tab predictably.
public struct TabRestoreToken: Codable, Sendable, Equatable, Hashable {
    public var lastCommittedURLString: String

    /// Optional scroll anchor (best-effort).
    ///
    /// Notes:
    /// - May be nil if not captured.
    /// - If present, higher layers may restore scroll position after load.
    public var scrollY: Double?

    /// Optional lightweight history summary (best-effort).
    ///
    /// - Important: WebKit does not provide a public API to *rehydrate* a full back/forward list.
    ///   This is intended for UI/policy/diagnostics and for best-effort user-visible context.
    public var backForwardListSummary: BackForwardListSummary?

    public init(
        lastCommittedURLString: String,
        scrollY: Double? = nil,
        backForwardListSummary: BackForwardListSummary? = nil
    ) {
        self.lastCommittedURLString = lastCommittedURLString
        self.scrollY = scrollY
        self.backForwardListSummary = backForwardListSummary
    }
}

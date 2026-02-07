import Foundation

public enum NavigationFailurePhase: String, Codable, Sendable {
    case provisional
    case committed
    case unknown
}

public enum NavigationFailureCategory: String, Codable, Sendable {
    case cancelled
    case offline
    case timedOut
    case dns
    case cannotConnect
    case tls
    case http
    case webContentProcessTerminated
    case blocked
    case unknown
}

/// Privacy-aware navigation failure record intended for diagnostics UI.
///
/// Note: This intentionally avoids storing a full URL path/query by default.
public struct NavigationFailureRecord: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var timestamp: Date

    public var phase: NavigationFailurePhase
    public var isMainFrame: Bool

    public var urlScheme: String?
    public var urlHost: String?

    public var category: NavigationFailureCategory

    public var errorDomain: String
    public var errorCode: Int

    /// Best-effort short message (should be redacted / non-sensitive).
    public var message: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        phase: NavigationFailurePhase,
        isMainFrame: Bool,
        urlScheme: String?,
        urlHost: String?,
        category: NavigationFailureCategory,
        errorDomain: String,
        errorCode: Int,
        message: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.phase = phase
        self.isMainFrame = isMainFrame
        self.urlScheme = urlScheme
        self.urlHost = urlHost
        self.category = category
        self.errorDomain = errorDomain
        self.errorCode = errorCode
        self.message = message
    }
}

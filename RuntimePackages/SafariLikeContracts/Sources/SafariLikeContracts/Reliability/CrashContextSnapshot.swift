import Foundation

public enum MemoryPressureLevel: String, Codable, Sendable, Hashable {
    case normal
    case warning
    case critical
    case unknown
}

/// Privacy-safe crash context snapshot.
///
/// Constraints:
/// - No URLs, titles, or user content.
/// - `lastUserAction` must be redacted (e.g., "cmd+l", "tap:newTab").
public struct CrashContextSnapshot: Codable, Sendable, Hashable {
    public var sceneID: String
    public var activeTabCount: Int
    public var activeWebViewCount: Int
    public var memoryPressureLevel: MemoryPressureLevel
    public var lastUserAction: String?

    public init(
        sceneID: String,
        activeTabCount: Int,
        activeWebViewCount: Int,
        memoryPressureLevel: MemoryPressureLevel,
        lastUserAction: String?
    ) {
        self.sceneID = sceneID
        self.activeTabCount = activeTabCount
        self.activeWebViewCount = activeWebViewCount
        self.memoryPressureLevel = memoryPressureLevel
        self.lastUserAction = lastUserAction
    }
}

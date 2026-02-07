import Foundation

public enum TelemetryEventType: String, Codable, Sendable, Hashable {
    case appLaunch
    case sceneCreated
    case sceneDestroyed
    case tabCreated
    case tabClosed
    case tabEvicted
    case navigationStarted
    case navigationFailed
    case downloadStarted
    case downloadCompleted
    case memoryWarning
    case parityAuditRun
}

/// Lightweight, local-only, privacy-safe telemetry.
///
/// Rules:
/// - No URLs, search queries, page titles, or user-entered text.
/// - `attributes` must be strictly non-PII (enforced by higher layers + audits).
public struct TelemetryEvent: Codable, Sendable, Hashable {
    public var type: TelemetryEventType
    public var timestamp: Date
    public var sceneID: String?
    public var attributes: [String: String]

    public init(
        type: TelemetryEventType,
        timestamp: Date = Date(),
        sceneID: String? = nil,
        attributes: [String: String] = [:]
    ) {
        self.type = type
        self.timestamp = timestamp
        self.sceneID = sceneID
        self.attributes = attributes
    }
}

public enum TelemetryPIIRule {
    /// Keys that are never allowed in telemetry attributes.
    public static let forbiddenKeySubstrings: [String] = [
        "url", "uri", "host", "domain", "path", "query", "search", "title", "content", "form"
    ]
}

public protocol TelemetryRecording: Sendable {
    func record(_ event: TelemetryEvent)
    func snapshot() -> [TelemetryEvent]
}

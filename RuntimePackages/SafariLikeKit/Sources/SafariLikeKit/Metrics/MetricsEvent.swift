import Foundation
import SafariLikeCoreKit
/// A single metrics event recorded by `MetricsCollector`.
public struct MetricsEvent: Codable, Sendable, Identifiable {
    public enum Kind: Codable, Sendable {
        /// Time spent from app/scene launch start to usable UI.
        case appLaunch(durationSeconds: TimeInterval)
        /// Time spent restoring tabs/session state (not necessarily creating WebViews).
        case tabRestore(durationSeconds: TimeInterval, tabCount: Int?)
        /// End-to-end latency for a navigation.
        case navigationLatency(durationSeconds: TimeInterval, url: String?)
        /// Cost of a plugin hook or policy check.
        case pluginCost(pluginID: String, phase: String, durationSeconds: TimeInterval, timedOut: Bool, failed: Bool)
        /// A memory pressure signal.
        case memoryPressure(level: MemoryPressureLevel, source: String?)
        /// A recovered (non-fatal) fault.
        case fault(domain: FaultDomain, message: String, pluginID: String?, tabID: UUID?, underlyingErrorDescription: String?)
    }
    public enum MemoryPressureLevel: String, Codable, Sendable {
        case unknown
        case warning
        case critical
    }
    public let id: UUID
    public let timestamp: Date
    public let kind: Kind
    public init(id: UUID = UUID(), timestamp: Date = Date(), kind: Kind) {
        self.id = id
        self.timestamp = timestamp
        self.kind = kind
    }
}

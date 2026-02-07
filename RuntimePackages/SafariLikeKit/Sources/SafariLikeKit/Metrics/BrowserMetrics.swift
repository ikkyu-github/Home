import Foundation
import SafariLikeCoreKit
/// Exportable per-window metrics snapshot.
///
/// Designed to answer: "อะไรช้า ก่อน user จะรู้".
public struct BrowserMetrics: Codable, Sendable {
    public struct DurationSample: Codable, Sendable {
        public let recordedAt: Date
        public let durationSeconds: TimeInterval
        public init(recordedAt: Date, durationSeconds: TimeInterval) {
            self.recordedAt = recordedAt
            self.durationSeconds = durationSeconds
        }
    }
    public struct NavigationLatencySample: Codable, Sendable {
        public let recordedAt: Date
        public let durationSeconds: TimeInterval
        public let url: String?
        public init(recordedAt: Date, durationSeconds: TimeInterval, url: String?) {
            self.recordedAt = recordedAt
            self.durationSeconds = durationSeconds
            self.url = url
        }
    }
    public struct PluginCostSample: Codable, Sendable {
        public let recordedAt: Date
        public let pluginID: String
        public let phase: String
        public let durationSeconds: TimeInterval
        public let timedOut: Bool
        public let failed: Bool
        public init(
            recordedAt: Date,
            pluginID: String,
            phase: String,
            durationSeconds: TimeInterval,
            timedOut: Bool,
            failed: Bool
        ) {
            self.recordedAt = recordedAt
            self.pluginID = pluginID
            self.phase = phase
            self.durationSeconds = durationSeconds
            self.timedOut = timedOut
            self.failed = failed
        }
    }
    public struct MemoryPressureEvent: Codable, Sendable {
        public let recordedAt: Date
        public let level: MetricsEvent.MemoryPressureLevel
        public let source: String?
        public init(recordedAt: Date, level: MetricsEvent.MemoryPressureLevel, source: String?) {
            self.recordedAt = recordedAt
            self.level = level
            self.source = source
        }
    }
    public struct FaultEvent: Codable, Sendable {
        public let recordedAt: Date
        public let domain: FaultDomain
        public let message: String
        public let pluginID: String?
        public let tabID: String?
        public let underlyingErrorDescription: String?
        public init(
            recordedAt: Date,
            domain: FaultDomain,
            message: String,
            pluginID: String?,
            tabID: String?,
            underlyingErrorDescription: String?
        ) {
            self.recordedAt = recordedAt
            self.domain = domain
            self.message = message
            self.pluginID = pluginID
            self.tabID = tabID
            self.underlyingErrorDescription = underlyingErrorDescription
        }
    }
    public let windowID: String
    public let sessionID: String?
    public let generatedAt: Date
    public var appLaunchTime: DurationSample?
    public var tabRestoreTime: DurationSample?
    public var navigationLatency: [NavigationLatencySample]
    public var pluginCost: [PluginCostSample]
    public var memoryPressureEvents: [MemoryPressureEvent]
    public var faults: [FaultEvent]
    /// Raw events (optional but useful for debugging). When exporting, this is typically included.
    public var events: [MetricsEvent]
    public init(
        windowID: String,
        sessionID: String? = nil,
        generatedAt: Date = Date(),
        appLaunchTime: DurationSample? = nil,
        tabRestoreTime: DurationSample? = nil,
        navigationLatency: [NavigationLatencySample] = [],
        pluginCost: [PluginCostSample] = [],
        memoryPressureEvents: [MemoryPressureEvent] = [],
        faults: [FaultEvent] = [],
        events: [MetricsEvent] = []
    ) {
        self.windowID = windowID
        self.sessionID = sessionID
        self.generatedAt = generatedAt
        self.appLaunchTime = appLaunchTime
        self.tabRestoreTime = tabRestoreTime
        self.navigationLatency = navigationLatency
        self.pluginCost = pluginCost
        self.memoryPressureEvents = memoryPressureEvents
        self.faults = faults
        self.events = events
    }
}

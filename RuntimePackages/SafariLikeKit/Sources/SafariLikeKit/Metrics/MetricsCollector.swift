import Foundation
import SafariLikeCoreKit
/// Thread-safe, per-window metrics collector.
///
/// This is intentionally lightweight and non-UI-facing. Callers can record timing/events
/// from anywhere, then export a JSON snapshot for diagnostics.
public actor MetricsCollector {
    public struct Configuration: Sendable {
        public var maxEvents: Int
        public init(maxEvents: Int = 2_000) {
            self.maxEvents = maxEvents
        }
    }
    private let windowID: UUID
    private let sessionID: UUID?
    private let configuration: Configuration
    /// Optional provider for pulling plugin metrics at export-time.
    /// This allows us to include `pluginCost` even if plugins record elsewhere.
    private let pluginMetricsProvider: (@Sendable () async -> [String: any PluginMetricsProviding]?)?
    private var events: [MetricsEvent] = []
    private var lastAppLaunchTime: BrowserMetrics.DurationSample?
    private var lastTabRestoreTime: BrowserMetrics.DurationSample?
    private var navigationLatencySamples: [BrowserMetrics.NavigationLatencySample] = []
    private var pluginCostSamples: [BrowserMetrics.PluginCostSample] = []
    private var memoryPressureEvents: [BrowserMetrics.MemoryPressureEvent] = []
    private var faultEvents: [BrowserMetrics.FaultEvent] = []
    public init(
        windowID: UUID,
        sessionID: UUID? = nil,
        configuration: Configuration = Configuration(),
        pluginMetricsProvider: (@Sendable () async -> [String: any PluginMetricsProviding]?)? = nil
    ) {
        self.windowID = windowID
        self.sessionID = sessionID
        self.configuration = configuration
        self.pluginMetricsProvider = pluginMetricsProvider
    }
    // MARK: - Recording
    public func recordAppLaunchTime(durationSeconds: TimeInterval, at date: Date = Date()) {
        lastAppLaunchTime = .init(recordedAt: date, durationSeconds: durationSeconds)
        append(.init(timestamp: date, kind: .appLaunch(durationSeconds: durationSeconds)))
    }
    public func recordTabRestoreTime(durationSeconds: TimeInterval, tabCount: Int? = nil, at date: Date = Date()) {
        lastTabRestoreTime = .init(recordedAt: date, durationSeconds: durationSeconds)
        append(.init(timestamp: date, kind: .tabRestore(durationSeconds: durationSeconds, tabCount: tabCount)))
    }
    public func recordNavigationLatency(durationSeconds: TimeInterval, url: String? = nil, at date: Date = Date()) {
        navigationLatencySamples.append(.init(recordedAt: date, durationSeconds: durationSeconds, url: url))
        append(.init(timestamp: date, kind: .navigationLatency(durationSeconds: durationSeconds, url: url)))
    }
    public func recordPluginCost(
        pluginID: String,
        phase: String,
        durationSeconds: TimeInterval,
        timedOut: Bool,
        failed: Bool,
        at date: Date = Date()
    ) {
        pluginCostSamples.append(
            .init(
                recordedAt: date,
                pluginID: pluginID,
                phase: phase,
                durationSeconds: durationSeconds,
                timedOut: timedOut,
                failed: failed
            )
        )
        append(
            .init(
                timestamp: date,
                kind: .pluginCost(
                    pluginID: pluginID,
                    phase: phase,
                    durationSeconds: durationSeconds,
                    timedOut: timedOut,
                    failed: failed
                )
            )
        )
    }
    public func recordMemoryPressure(level: MetricsEvent.MemoryPressureLevel, source: String? = nil, at date: Date = Date()) {
        memoryPressureEvents.append(.init(recordedAt: date, level: level, source: source))
        append(.init(timestamp: date, kind: .memoryPressure(level: level, source: source)))
    }
    public func recordFault(
        domain: FaultDomain,
        message: String,
        pluginID: String? = nil,
        tabID: UUID? = nil,
        underlyingErrorDescription: String? = nil,
        at date: Date = Date()
    ) {
        faultEvents.append(
            .init(
                recordedAt: date,
                domain: domain,
                message: message,
                pluginID: pluginID,
                tabID: tabID?.uuidString,
                underlyingErrorDescription: underlyingErrorDescription
            )
        )
        append(
            .init(
                timestamp: date,
                kind: .fault(
                    domain: domain,
                    message: message,
                    pluginID: pluginID,
                    tabID: tabID,
                    underlyingErrorDescription: underlyingErrorDescription
                )
            )
        )
    }
    public func record(_ event: MetricsEvent) {
        switch event.kind {
        case .appLaunch(let durationSeconds):
            lastAppLaunchTime = .init(recordedAt: event.timestamp, durationSeconds: durationSeconds)
        case .tabRestore(let durationSeconds, _):
            lastTabRestoreTime = .init(recordedAt: event.timestamp, durationSeconds: durationSeconds)
        case .navigationLatency(let durationSeconds, let url):
            navigationLatencySamples.append(.init(recordedAt: event.timestamp, durationSeconds: durationSeconds, url: url))
        case .pluginCost(let pluginID, let phase, let durationSeconds, let timedOut, let failed):
            pluginCostSamples.append(
                .init(
                    recordedAt: event.timestamp,
                    pluginID: pluginID,
                    phase: phase,
                    durationSeconds: durationSeconds,
                    timedOut: timedOut,
                    failed: failed
                )
            )
        case .memoryPressure(let level, let source):
            memoryPressureEvents.append(.init(recordedAt: event.timestamp, level: level, source: source))
        case .fault(let domain, let message, let pluginID, let tabID, let underlyingErrorDescription):
            faultEvents.append(
                .init(
                    recordedAt: event.timestamp,
                    domain: domain,
                    message: message,
                    pluginID: pluginID,
                    tabID: tabID?.uuidString,
                    underlyingErrorDescription: underlyingErrorDescription
                )
            )
        }
        append(event)
    }
    public func reset() {
        events.removeAll(keepingCapacity: false)
        lastAppLaunchTime = nil
        lastTabRestoreTime = nil
        navigationLatencySamples.removeAll(keepingCapacity: false)
        pluginCostSamples.removeAll(keepingCapacity: false)
        memoryPressureEvents.removeAll(keepingCapacity: false)
        faultEvents.removeAll(keepingCapacity: false)
    }
    // MARK: - Export
    public func snapshot(includeEvents: Bool = true) async -> BrowserMetrics {
        var pluginCosts = pluginCostSamples
        if let provider = pluginMetricsProvider {
            if let pluginMetricsByID = await provider() {
                // Map the latest plugin metrics into PluginCost samples so exports stay self-contained.
                // Note: PluginMetricsStore currently tracks only the latest duration per hook.
                let now = Date()
                for (pluginID, metrics) in pluginMetricsByID {
                    if let load = metrics.timings["onLoad"] {
                        pluginCosts.append(.init(recordedAt: now, pluginID: pluginID, phase: "onLoad", durationSeconds: load, timedOut: false, failed: false))
                    }
                    if let enable = metrics.timings["onEnable"] {
                        pluginCosts.append(.init(recordedAt: now, pluginID: pluginID, phase: "onEnable", durationSeconds: enable, timedOut: false, failed: false))
                    }
                    if let policy = metrics.timings["policyCheck"] {
                        pluginCosts.append(.init(recordedAt: now, pluginID: pluginID, phase: "policyCheck", durationSeconds: policy, timedOut: false, failed: false))
                    }
                    let failureCount = metrics.counters["failureCount"] ?? 0
                    if failureCount > 0 {
                        // Represent failures as a zero-duration record (failures are counts, not timings).
                        pluginCosts.append(.init(recordedAt: now, pluginID: pluginID, phase: "failureCount=\(failureCount)", durationSeconds: 0, timedOut: false, failed: true))
                    }
                }
            }
        }
        return BrowserMetrics(
            windowID: windowID.uuidString,
            sessionID: sessionID?.uuidString,
            generatedAt: Date(),
            appLaunchTime: lastAppLaunchTime,
            tabRestoreTime: lastTabRestoreTime,
            navigationLatency: navigationLatencySamples,
            pluginCost: pluginCosts,
            memoryPressureEvents: memoryPressureEvents,
            faults: faultEvents,
            events: includeEvents ? events : []
        )
    }
    public func exportJSON(prettyPrinted: Bool = true, includeEvents: Bool = true) async throws -> String {
        let snapshot = await snapshot(includeEvents: includeEvents)
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        return String(decoding: data, as: UTF8.self)
    }
    // MARK: - Internals
    private func append(_ event: MetricsEvent) {
        events.append(event)
        trimIfNeeded()
    }
    private func trimIfNeeded() {
        let limit = configuration.maxEvents
        guard limit > 0, events.count > limit else { return }
        let overflow = events.count - limit
        if overflow > 0 {
            events.removeFirst(overflow)
        }
        // Keep derived arrays roughly aligned by trimming oldest items too.
        if navigationLatencySamples.count > limit {
            navigationLatencySamples.removeFirst(navigationLatencySamples.count - limit)
        }
        if pluginCostSamples.count > limit {
            pluginCostSamples.removeFirst(pluginCostSamples.count - limit)
        }
        if memoryPressureEvents.count > limit {
            memoryPressureEvents.removeFirst(memoryPressureEvents.count - limit)
        }
        if faultEvents.count > limit {
            faultEvents.removeFirst(faultEvents.count - limit)
        }
    }
}

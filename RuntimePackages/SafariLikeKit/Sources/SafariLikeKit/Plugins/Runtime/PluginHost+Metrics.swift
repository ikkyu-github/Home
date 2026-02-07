import Foundation

// MARK: - Plugin metrics (used by RuntimePluginRegistry + MetricsCollector)
@MainActor
final class PluginMetricsStore {
    struct PluginMetrics: Sendable, PluginMetricsProviding {
        var loadTime: TimeInterval?
        var enableTime: TimeInterval?
        var policyCheckDuration: TimeInterval?
        var failureCount: Int
        init(
            loadTime: TimeInterval? = nil,
            enableTime: TimeInterval? = nil,
            policyCheckDuration: TimeInterval? = nil,
            failureCount: Int = 0
        ) {
            self.loadTime = loadTime
            self.enableTime = enableTime
            self.policyCheckDuration = policyCheckDuration
            self.failureCount = failureCount
        }

        var counters: [String: Int] {
            ["failureCount": failureCount]
        }

        var timings: [String: TimeInterval] {
            var values: [String: TimeInterval] = [:]
            if let loadTime { values["onLoad"] = loadTime }
            if let enableTime { values["onEnable"] = enableTime }
            if let policyCheckDuration { values["policyCheck"] = policyCheckDuration }
            return values
        }

        var flags: [String: Bool] {
            [:]
        }
    }

    private(set) var metricsByPluginID: [String: PluginMetrics] = [:]

    func recordLoad(pluginID: String, durationSeconds: TimeInterval) {
        var m = metricsByPluginID[pluginID] ?? PluginMetrics()
        m.loadTime = durationSeconds
        metricsByPluginID[pluginID] = m
    }

    func recordEnable(pluginID: String, durationSeconds: TimeInterval) {
        var m = metricsByPluginID[pluginID] ?? PluginMetrics()
        m.enableTime = durationSeconds
        metricsByPluginID[pluginID] = m
    }

    func recordPolicyCheck(pluginID: String, durationSeconds: TimeInterval) {
        var m = metricsByPluginID[pluginID] ?? PluginMetrics()
        m.policyCheckDuration = durationSeconds
        metricsByPluginID[pluginID] = m
    }

    func incrementFailure(pluginID: String) {
        var m = metricsByPluginID[pluginID] ?? PluginMetrics()
        m.failureCount += 1
        metricsByPluginID[pluginID] = m
    }

    func reset(pluginID: String) {
        metricsByPluginID.removeValue(forKey: pluginID)
    }
}

extension PluginHost {
    // MARK: - Metrics
    // RuntimePluginRegistry owns PluginMetricsStore; PluginHost doesn't add extra logic here.

    func pluginMetricsSnapshot() -> [String: any PluginMetricsProviding] {
        pluginRegistry.metrics.metricsByPluginID.mapValues { $0 as any PluginMetricsProviding }
    }
}

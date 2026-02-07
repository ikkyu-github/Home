import Foundation
import SafariLikeCoreKit
/// Per-window container for state that must never be shared across windows.
///
/// Rules:
/// - 1 window = 1 session
/// - plugins do not share across windows
@MainActor
final class BrowserWindowContext {
    let windowID: UUID
    let sessionID: UUID
    /// Per-window plugin registry instance.
    let pluginRegistry: RuntimePluginRegistry
    /// Per-window metrics collector (currently backed by the plugin registry).
    let metricsCollector: PluginMetricsStore
    /// Per-window browser metrics collector (thread-safe, exportable).
    let browserMetrics: MetricsCollector
    /// Per-window fault manager (configured by lifecycle registration).
    var faultManager: FaultManager?
    init(
        windowID: UUID,
        sessionID: UUID = UUID(),
        pluginRegistry: RuntimePluginRegistry? = nil,
        pluginMetricsProvider: (@Sendable () async -> [String: any PluginMetricsProviding]?)? = nil
    ) {
        let pluginRegistry = pluginRegistry ?? RuntimePluginRegistry()
        self.windowID = windowID
        self.sessionID = sessionID
        self.pluginRegistry = pluginRegistry
        self.metricsCollector = pluginRegistry.metrics
        self.browserMetrics = MetricsCollector(
            windowID: windowID,
            sessionID: sessionID,
            pluginMetricsProvider: pluginMetricsProvider
        )
    }
}

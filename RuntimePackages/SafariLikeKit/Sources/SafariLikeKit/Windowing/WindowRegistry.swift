import Foundation
import os
import SafariLikeCoreKit
/// Tracks per-window contexts so multi-window state never mixes.
@MainActor
final class WindowRegistry {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "WindowRegistry")
    private(set) var contextsByWindowID: [UUID: BrowserWindowContext] = [:]
    init() {}
    /// Called when a scene/window connects.
    ///
    /// - Returns: The per-window context, creating it if needed.
    @discardableResult
    func onSceneConnect(
        windowID: UUID,
        pluginMetricsProvider: (@Sendable () async -> [String: any PluginMetricsProviding]?)? = nil
    ) -> BrowserWindowContext {
        if let existing = contextsByWindowID[windowID] {
            return existing
        }
        let created = BrowserWindowContext(windowID: windowID, pluginMetricsProvider: pluginMetricsProvider)
        contextsByWindowID[windowID] = created
        Self.logger.info("Scene connected windowID=\(windowID.uuidString, privacy: .public) sessionID=\(created.sessionID.uuidString, privacy: .public)")
        return created
    }
    /// Called when a scene/window disconnects.
    func onSceneDisconnect(windowID: UUID) {
        guard let existing = contextsByWindowID.removeValue(forKey: windowID) else { return }
        Self.logger.info("Scene disconnected windowID=\(windowID.uuidString, privacy: .public) sessionID=\(existing.sessionID.uuidString, privacy: .public)")
    }
    func context(for windowID: UUID) -> BrowserWindowContext? {
        contextsByWindowID[windowID]
    }
}

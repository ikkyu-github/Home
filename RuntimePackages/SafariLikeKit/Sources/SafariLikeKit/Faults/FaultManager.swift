import Foundation
import os
import SafariLikeCoreKit
/// Central, per-window fault handler.
///
/// Goals:
/// - Apply domain-appropriate recovery (disable plugin, discard web view, re-render UI)
/// - Always log + record metrics
/// - Avoid crashing unless absolutely required
@MainActor
public final class FaultManager {
    public struct Fault: Sendable {
        public let domain: FaultDomain
        public let message: String
        /// Optional details.
        public let pluginID: String?
        public let tabID: UUID?
        public let underlyingErrorDescription: String?
        public init(
            domain: FaultDomain,
            message: String,
            pluginID: String? = nil,
            tabID: UUID? = nil,
            underlyingErrorDescription: String? = nil
        ) {
            self.domain = domain
            self.message = message
            self.pluginID = pluginID
            self.tabID = tabID
            self.underlyingErrorDescription = underlyingErrorDescription
        }
    }
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "FaultManager")
    private let windowID: UUID
    private let metrics: MetricsCollector
    private let disablePlugin: (@MainActor @Sendable (String) -> Void)?
    private let discardWebView: (@MainActor @Sendable (UUID?) -> Void)?
    private let requestUIRerender: (@MainActor @Sendable () -> Void)?
    public init(
        windowID: UUID,
        metrics: MetricsCollector,
        disablePlugin: (@MainActor @Sendable (String) -> Void)? = nil,
        discardWebView: (@MainActor @Sendable (UUID?) -> Void)? = nil,
        requestUIRerender: (@MainActor @Sendable () -> Void)? = nil
    ) {
        self.windowID = windowID
        self.metrics = metrics
        self.disablePlugin = disablePlugin
        self.discardWebView = discardWebView
        self.requestUIRerender = requestUIRerender
    }
    public func handle(_ fault: Fault) {
        // 1) Log (never crash here)
        if let pluginID = fault.pluginID {
            Self.logger.error("Fault domain=\(fault.domain.rawValue, privacy: .public) windowID=\(self.windowID.uuidString, privacy: .public) pluginID=\(pluginID, privacy: .public) msg=\(fault.message, privacy: .public)")
        } else {
            Self.logger.error("Fault domain=\(fault.domain.rawValue, privacy: .public) windowID=\(self.windowID.uuidString, privacy: .public) msg=\(fault.message, privacy: .public)")
        }
        // 2) Metrics (best-effort; do not block UI)
        Task {
            await metrics.recordFault(
                domain: fault.domain,
                message: fault.message,
                pluginID: fault.pluginID,
                tabID: fault.tabID,
                underlyingErrorDescription: fault.underlyingErrorDescription
            )
        }
        // 3) Recovery (best-effort)
        switch fault.domain {
        case .plugin:
            if let pluginID = fault.pluginID {
                disablePlugin?(pluginID)
            }
        case .webRuntime:
            discardWebView?(fault.tabID)
        case .ui:
            requestUIRerender?()
        case .persistence:
            // Best effort: do not crash. Persistence retry policies can be layered later.
            break
        }
    }
    // Convenience helpers
    public func pluginFault(pluginID: String, message: String, error: Error? = nil) {
        handle(
            Fault(
                domain: .plugin,
                message: message,
                pluginID: pluginID,
                underlyingErrorDescription: error.map { String(describing: $0) }
            )
        )
    }
    public func webRuntimeFault(tabID: UUID? = nil, message: String, error: Error? = nil) {
        handle(
            Fault(
                domain: .webRuntime,
                message: message,
                tabID: tabID,
                underlyingErrorDescription: error.map { String(describing: $0) }
            )
        )
    }
    public func uiFault(message: String, error: Error? = nil) {
        handle(
            Fault(
                domain: .ui,
                message: message,
                underlyingErrorDescription: error.map { String(describing: $0) }
            )
        )
    }
    public func persistenceFault(message: String, error: Error? = nil) {
        handle(
            Fault(
                domain: .persistence,
                message: message,
                underlyingErrorDescription: error.map { String(describing: $0) }
            )
        )
    }
}

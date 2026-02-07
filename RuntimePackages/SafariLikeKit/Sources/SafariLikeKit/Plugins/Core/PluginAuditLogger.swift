import Foundation
import os
import SafariLikeContracts
import SafariLikeCoreKit
enum PluginAuditLogger {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "PluginAudit")
    static func handler() -> PluginContext.AuditHandler {
        { event in
            // Keep logs compact to avoid leaking too much data.
            // URL is included only when provided by the caller.
            let url = event.url ?? ""
            if url.isEmpty {
                logger.info("audit plugin=\(event.pluginID, privacy: .public) action=\(event.action.rawValue, privacy: .public) cap=\(event.capability.rawValue, privacy: .public) perm=\(String(describing: event.requiredPermission?.rawValue), privacy: .public)")
            } else {
                logger.info("audit plugin=\(event.pluginID, privacy: .public) action=\(event.action.rawValue, privacy: .public) cap=\(event.capability.rawValue, privacy: .public) perm=\(String(describing: event.requiredPermission?.rawValue), privacy: .public) url=\(url, privacy: .private(mask: .hash))")
            }
        }
    }
}

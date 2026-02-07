import Foundation
import os
import SafariLikeCoreKit
private final class BrowserLogBundleToken {}
enum BrowserLog {
    private static let subsystem: String = {
        // Use the framework's bundle identifier instead of Bundle.main
        let bundle = Bundle(for: BrowserLogBundleToken.self)
        return bundle.bundleIdentifier ?? "SafariLikeKit"
    }()
    private static let logger = Logger(
        subsystem: subsystem,
        category: "Browser"
    )
    static func warn(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }
    static func webError(_ message: String) {
        logger.error("Web ❌ \(message, privacy: .public)")
    }
    static func storageError(_ message: String) {
        logger.error("Storage ❌ \(message, privacy: .public)")
    }
}

import Foundation
import os

enum LaunchLog {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "webOS",
        category: "Launch"
    )

    static func mark(_ message: String) {
        #if DEBUG
        logger.notice("LAUNCH: \(message, privacy: .public)")
        #endif
    }
}

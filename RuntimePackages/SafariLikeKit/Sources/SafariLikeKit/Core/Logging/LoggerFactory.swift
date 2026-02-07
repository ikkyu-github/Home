import os
import SafariLikeCoreKit
internal enum LoggerFactory {
    static let subsystem = "SafariLikeKit"
    static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}

import os

public enum DiagnosticsSubsystem: String {
    case runtime
    case web
    case session
    case plugin
}

public struct Diagnostics {
    private static let enabledKey = "app.diagnostics.enabled"

    private static var isEnabled: Bool {
        if let value = UserDefaults.standard.object(forKey: enabledKey) as? Bool {
            return value
        }
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    public static func logger(subsystem: DiagnosticsSubsystem, category: String) -> Logger {
        Logger(subsystem: "com.ikkyu.webOS." + subsystem.rawValue, category: category)
    }

    public static func logError(_ message: String, subsystem: DiagnosticsSubsystem, category: String = "error") {
        guard isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.error("\(message, privacy: .public)")
    }

    public static func logInfo(_ message: String, subsystem: DiagnosticsSubsystem, category: String = "info") {
        guard isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.info("\(message, privacy: .public)")
    }

    public static func logDebug(_ message: String, subsystem: DiagnosticsSubsystem, category: String = "debug") {
        guard isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.debug("\(message, privacy: .public)")
    }
}

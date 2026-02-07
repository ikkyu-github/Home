import os

public struct Diagnostics {
    public typealias Subsystem = LogSubsystem

    public enum Category: Sendable, Hashable {
        case debug
        case info
        case error
        case launch
        case custom(String)

        var value: String {
            switch self {
            case .debug: return "debug"
            case .info: return "info"
            case .error: return "error"
            case .launch: return "Launch"
            case .custom(let raw): return raw
            }
        }
    }
    public static func logger(subsystem: LogSubsystem, category: String) -> Logger {
        Logger(subsystem: "com.ikkyu.webOS." + subsystem.rawValue, category: category)
    }

    public static func logError(_ message: String, subsystem: LogSubsystem, category: String = "error") -> Void {
        guard DiagnosticsGate.isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.error("\(message, privacy: .public)")
    }

    public static func logError(_ message: String, subsystem: Subsystem, category: Category) -> Void {
        logError(message, subsystem: subsystem, category: category.value)
    }

    public static func logInfo(_ message: String, subsystem: LogSubsystem, category: String = "info") -> Void {
        guard DiagnosticsGate.isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.info("\(message, privacy: .public)")
    }

    public static func logInfo(_ message: String, subsystem: Subsystem, category: Category) -> Void {
        logInfo(message, subsystem: subsystem, category: category.value)
    }

    public static func logDebug(_ message: String, subsystem: LogSubsystem, category: String = "debug") -> Void {
        guard DiagnosticsGate.isEnabled else { return }
        let logger = self.logger(subsystem: subsystem, category: category)
        logger.debug("\(message, privacy: .public)")
    }

    public static func logDebug(_ message: String, subsystem: Subsystem, category: Category) -> Void {
        logDebug(message, subsystem: subsystem, category: category.value)
    }
}

import Foundation

public struct ReplayDiagnostics: Sendable, Equatable {

    public struct Entry: Sendable, Equatable {
        public enum Level: String, Sendable, Equatable {
            case info
            case warning
        }

        public var level: Level
        public var message: String
        public var eventID: UUID?

        public init(level: Level, message: String, eventID: UUID? = nil) {
            self.level = level
            self.message = message
            self.eventID = eventID
        }
    }

    public var entries: [Entry]

    public var outOfOrderEventsDetected: Int
    public var droppedEvents: Int
    public var placeholderTabsCreated: Int
    public var migrationsApplied: Int

    public init(
        entries: [Entry] = [],
        outOfOrderEventsDetected: Int = 0,
        droppedEvents: Int = 0,
        placeholderTabsCreated: Int = 0,
        migrationsApplied: Int = 0
    ) {
        self.entries = entries
        self.outOfOrderEventsDetected = outOfOrderEventsDetected
        self.droppedEvents = droppedEvents
        self.placeholderTabsCreated = placeholderTabsCreated
        self.migrationsApplied = migrationsApplied
    }

    public mutating func info(_ message: String, eventID: UUID? = nil) {
        entries.append(Entry(level: .info, message: message, eventID: eventID))
    }

    public mutating func warn(_ message: String, eventID: UUID? = nil) {
        entries.append(Entry(level: .warning, message: message, eventID: eventID))
    }
}

#if DEBUG
import os

enum ReplayDiagnosticsLogger {
    static let logger = Logger(subsystem: "com.ikkyu.BrowserCore", category: "Replay")

    static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}
#endif

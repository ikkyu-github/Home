import Foundation
import Combine
import SafariLikeCoreKit
public struct LaunchMetricEvent: Sendable {
    public let name: String
    public let timestamp: Date
    public let thread: String
    public let note: String?
    public init(name: String, timestamp: Date = Date(), thread: String, note: String? = nil) {
        self.name = name
        self.timestamp = timestamp
        self.thread = thread
        self.note = note
    }
}
@MainActor
public final class LaunchTracer: ObservableObject {
    /// SAFE SINGLETON:
    /// - Process-wide launch timing tracer.
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = LaunchTracer()
    @Published public private(set) var events: [LaunchMetricEvent] = []
    private init() {}
    public func mark(_ name: String, _ note: String? = nil) {
        let threadLabel = Thread.isMainThread ? "main" : "bg"
        let event = LaunchMetricEvent(name: name, thread: threadLabel, note: note)
        events.append(event)
        if events.count > 200 {
            events.removeFirst(events.count - 200)
        }
        #if DEBUG
        if name == "app.start.end" {
            dumpToConsoleIfNeeded()
        }
        #endif
    }
    #if DEBUG
    public func dumpToConsoleIfNeeded() {
        let lines = events.map { event in
            let noteSuffix = event.note.map { " (\($0))" } ?? ""
            return "[LaunchTracer] \(event.timestamp) [\(event.thread)] \(event.name)\(noteSuffix)"
        }
        lines.forEach {
            Diagnostics.logDebug(
                $0,
                subsystem: .runtime,
                category: "LaunchTracer"
            )
        }
    }
    #endif
}

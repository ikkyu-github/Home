import Foundation
import SafariLikeCoreKit
/// Lightweight, UI-agnostic performance tracing.
///
/// - Uses monotonic timestamps (`DispatchTime.uptimeNanoseconds`) instead of `Date`.
/// - Supports nested traces via a per-thread stack.
/// - Designed to be callable from Core/Engine/Tab/Plugin code.
public final class PerformanceTracer {
    public typealias TraceID = UUID
    public typealias Metadata = [String: String]
    public struct Trace: Sendable {
        public let id: TraceID
        public let name: String
        public let parentID: TraceID?
        public let startTimeNanos: UInt64
        public var endTimeNanos: UInt64?
        public var metadata: Metadata
        public var durationNanos: UInt64? {
            guard let endTimeNanos else { return nil }
            return endTimeNanos &- startTimeNanos
        }
        public init(
            id: TraceID,
            name: String,
            parentID: TraceID?,
            startTimeNanos: UInt64,
            endTimeNanos: UInt64? = nil,
            metadata: Metadata
        ) {
            self.id = id
            self.name = name
            self.parentID = parentID
            self.startTimeNanos = startTimeNanos
            self.endTimeNanos = endTimeNanos
            self.metadata = metadata
        }
    }
    public struct InstantEvent: Sendable {
        public let name: String
        public let timeNanos: UInt64
        public let parentID: TraceID?
        public let metadata: Metadata
        public init(name: String, timeNanos: UInt64, parentID: TraceID?, metadata: Metadata) {
            self.name = name
            self.timeNanos = timeNanos
            self.parentID = parentID
            self.metadata = metadata
        }
    }
    public enum Event: Sendable {
        case traceStarted(Trace)
        case traceEnded(Trace)
        case instant(InstantEvent)
    }
    /// SAFE SINGLETON:
    /// - Process-wide perf tracer; aggregates events.
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = PerformanceTracer()
    /// Enable/disable tracing with a cheap runtime check.
    public var isEnabled: Bool = true
    /// Optional event sink (e.g., to feed diagnostics or logging).
    /// Called outside internal locks.
    public var onEvent: (@Sendable (Event) -> Void)?
    /// Max number of completed traces/events kept in memory (best-effort).
    public var maxStored: Int = 5_000
    private let lock = NSLock()
    private var activeTraces: [TraceID: Trace] = [:]
    private var completedTraces: [Trace] = []
    private var instantEvents: [InstantEvent] = []
    private init() {}
    // MARK: - Public API
    /// Starts a trace using a centralized metric name.
    @discardableResult
    public func startTrace(_ metric: SafariPerformanceMetricName, metadata: Metadata = [:]) -> TraceID {
        startTrace(metric.name, metadata: metadata)
    }
    /// Starts a trace and returns a trace identifier.
    ///
    /// Nested traces are automatically linked using the current thread's active trace stack.
    @discardableResult
    public func startTrace(_ name: String, metadata: Metadata = [:]) -> TraceID {
        guard isEnabled else { return UUID() }
        let now = Self.monotonicNowNanos()
        let parentID = Self.currentThreadTraceStack().last
        let traceID = UUID()
        let trace = Trace(id: traceID, name: name, parentID: parentID, startTimeNanos: now, metadata: metadata)
        var handler: (@Sendable (Event) -> Void)?
        lock.lock()
        activeTraces[traceID] = trace
        handler = onEvent
        lock.unlock()
        Self.pushThreadTrace(traceID)
        handler?(.traceStarted(trace))
        return traceID
    }
    /// Ends a trace.
    ///
    /// If the trace ID is unknown, this is a no-op.
    public func endTrace(_ traceID: TraceID) {
        guard isEnabled else { return }
        let now = Self.monotonicNowNanos()
        var endedTrace: Trace?
        var handler: (@Sendable (Event) -> Void)?
        lock.lock()
        if var trace = activeTraces.removeValue(forKey: traceID) {
            trace.endTimeNanos = now
            endedTrace = trace
            completedTraces.append(trace)
            trimIfNeeded()
        }
        handler = onEvent
        lock.unlock()
        Self.popThreadTrace(traceID)
        if let endedTrace {
            handler?(.traceEnded(endedTrace))
        }
    }
    /// Records an instant event (optionally associated with the current trace context).
    public func instantEvent(_ metric: SafariPerformanceMetricName, metadata: Metadata = [:]) {
        instantEvent(metric.name, metadata: metadata)
    }
    public func instantEvent(_ name: String, metadata: Metadata = [:]) {
        guard isEnabled else { return }
        let now = Self.monotonicNowNanos()
        let parentID = Self.currentThreadTraceStack().last
        let event = InstantEvent(name: name, timeNanos: now, parentID: parentID, metadata: metadata)
        var handler: (@Sendable (Event) -> Void)?
        lock.lock()
        instantEvents.append(event)
        trimIfNeeded()
        handler = onEvent
        lock.unlock()
        handler?(.instant(event))
    }
    // MARK: - Snapshot (optional)
    /// Returns a point-in-time snapshot for diagnostics/testing.
    public func snapshot() -> (active: [Trace], completed: [Trace], instants: [InstantEvent]) {
        lock.lock()
        let active = Array(activeTraces.values)
        let completed = completedTraces
        let instants = instantEvents
        lock.unlock()
        return (active: active, completed: completed, instants: instants)
    }
    // MARK: - Internals
    private func trimIfNeeded() {
        let limit = maxStored
        guard limit > 0 else {
            completedTraces.removeAll(keepingCapacity: false)
            instantEvents.removeAll(keepingCapacity: false)
            return
        }
        if completedTraces.count > limit {
            completedTraces.removeFirst(completedTraces.count - limit)
        }
        if instantEvents.count > limit {
            instantEvents.removeFirst(instantEvents.count - limit)
        }
    }
    private static func monotonicNowNanos() -> UInt64 {
        DispatchTime.now().uptimeNanoseconds
    }
    // MARK: - Per-thread nesting context
    private static let threadStackKey = "SafariLikeKit.PerformanceTracer.traceStack"
    private static func currentThreadTraceStack() -> [TraceID] {
        let dict = Thread.current.threadDictionary
        return dict[threadStackKey] as? [TraceID] ?? []
    }
    private static func pushThreadTrace(_ id: TraceID) {
        let dict = Thread.current.threadDictionary
        var stack = dict[threadStackKey] as? [TraceID] ?? []
        stack.append(id)
        dict[threadStackKey] = stack
    }
    private static func popThreadTrace(_ id: TraceID) {
        let dict = Thread.current.threadDictionary
        guard var stack = dict[threadStackKey] as? [TraceID], !stack.isEmpty else { return }
        if stack.last == id {
            stack.removeLast()
        } else if let idx = stack.lastIndex(of: id) {
            stack.remove(at: idx)
        } else {
            return
        }
        if stack.isEmpty {
            dict.removeObject(forKey: threadStackKey as NSString)
        } else {
            dict[threadStackKey] = stack
        }
    }
}

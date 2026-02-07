import Foundation
import SafariLikeCoreKit
@MainActor
public final class RuntimeMetrics {
    public enum Counter: String {
        case runtimeInvariantViolation
        case tabCreated
        case tabClosed
        case tabSelected
        case tabActivated
        case tabBound
        case tabUnbound
        case webViewActivated
        case webViewDeactivated
        case renderBudgetFreeze
        case renderBudgetEvict
        case snapshotCaptured
        case pluginHookFailure
        case pluginDisabled
        case pluginViolation
    }
    /// SAFE SINGLETON:
    /// - Process-wide counters/telemetry (aggregated).
    /// - Must not store per-window/scene/tab mutable state.
    public static let shared = RuntimeMetrics()
    private var counters: [Counter: Int] = [:]
    private init() {}
    public func increment(_ counter: Counter, by amount: Int = 1) {
        guard DiagnosticsGate.isEnabled else { return }
        counters[counter, default: 0] += amount
    }
    public func snapshotCounters() -> [String: Int] {
        counters.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key.rawValue] = entry.value
        }
    }
    public func reset() {
        counters.removeAll()
    }
}

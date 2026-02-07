import Foundation

/// Read-only plugin metrics surface exposed across the plugin boundary.
///
/// This intentionally avoids referencing any concrete plugin/runtime types.
public protocol PluginMetricsProviding: Sendable {
    /// Counters such as error/failure counts.
    var counters: [String: Int] { get }

    /// Timing measurements in seconds.
    var timings: [String: TimeInterval] { get }

    /// Boolean flags for simple state.
    var flags: [String: Bool] { get }
}

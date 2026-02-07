import Foundation
import SafariLikeKit

/// App-target glue for SafariLikeKit PerformanceTracer.
///
/// Goal: ensure the Performance panel shows real numbers (not "—") by
/// starting the app launch trace early and marking key milestones.
@MainActor
enum AppPerformance {
    private static var launchTraceID: PerformanceTracer.TraceID?

    static func startLaunchIfNeeded() {
        guard launchTraceID == nil else { return }
        launchTraceID = PerformanceTracer.shared.startTrace(.appLaunch)
    }

    static func markFirstUIRendered() {
        PerformanceTracer.shared.instantEvent(.firstUIRendered)
    }

    static func markFirstWebViewReady() {
        PerformanceTracer.shared.instantEvent(.firstWebViewReady)
    }

    static func endLaunchIfNeeded() {
        guard let id = launchTraceID else { return }
        PerformanceTracer.shared.endTrace(id)
        launchTraceID = nil
    }
}

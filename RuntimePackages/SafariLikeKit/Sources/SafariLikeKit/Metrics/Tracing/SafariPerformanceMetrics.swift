import Foundation
import SafariLikeCoreKit
/// Centralized, stable metric names for performance tracing.
///
/// Policy:
/// - Do not introduce ad-hoc string literals for metric names elsewhere.
/// - Add new metric names here and reference via `SafariPerformanceMetricName`.
public enum SafariPerformanceMetricName: String, Sendable, CaseIterable {
    // MARK: - App launch
    /// Overall app launch trace (started at process/app start, ended when interactive).
    case appLaunch = "app.launch"
    /// Instant event: first root UI rendered (first frame on-screen).
    case firstUIRendered = "first.ui.rendered"
    /// Instant event: first WebView ready/created.
    case firstWebViewReady = "first.webview.ready"
    /// Time from launch start to first usable UI.
    case appLaunchToFirstUI = "app.launch.to.first.ui"
    /// Time from launch start to first WebView creation/ready.
    case appLaunchToFirstWebView = "app.launch.to.first.webview"
    // MARK: - Tabs
    /// Tab lifecycle transition duration (freeze/resume/restore to usable).
    case tabLifecycleTransition = "tab.lifecycle.transition"
    /// Time from tab activation to first paint.
    case tabActivateToFirstPaint = "tab.activate.to.first.paint"
    /// Time from tab/session restore start to interactive state.
    case tabRestoreToInteractive = "tab.restore.to.interactive"
    // MARK: - Session Restore
    /// Trace: overall session restore from start to interactive.
    case sessionRestoreTotal = "session.restore.total"
    /// Instant event: Phase A completed and UI can render placeholders.
    case sessionRestorePhaseAUIReady = "session.restore.phaseA.uiReady"
    /// Instant event: Phase B first visible WebView attached/ready.
    case sessionRestorePhaseBFirstWebReady = "session.restore.phaseB.firstWebReady"
    // MARK: - Engine
    /// Duration of handling a memory pressure event.
    case engineMemoryPressureHandle = "engine.memory.pressure.handle"
    /// Instant event: OS memory pressure signal received.
    case memoryPressureReceived = "memory.pressure.received"
    /// Trace: memory pressure mitigation window.
    case memoryPressureMitigation = "memory.pressure.mitigation"
    /// Instant event: freeze tab step.
    case memoryPressureFreezeTab = "memory.pressure.step.freeze.tab"
    /// Instant event: evict tab step.
    case memoryPressureEvictTab = "memory.pressure.step.evict.tab"
    /// Instant event: release WebView step.
    case memoryPressureReleaseWebView = "memory.pressure.step.release.webview"
    /// Instant event: memory considered stable (mitigation window ended).
    case memoryPressureStable = "memory.pressure.stable"
    // MARK: - Plugins
    /// Trace: plugin attach (installation/registration) work.
    case pluginAttach = "plugin.attach"
    /// Instant event: plugin exceeded performance threshold.
    case pluginPerformanceViolation = "plugin.performance.violation"
    // MARK: - Snapshots
    /// Duration to capture a snapshot/thumbnail.
    case snapshotCaptureDuration = "snapshot.capture.duration"
    public var name: String { rawValue }
}

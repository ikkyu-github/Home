import Foundation
import Combine
import SafariLikeCoreKit
/// Shared performance metrics model used by the debug overlay and Settings.
///
/// NOTE: This model compiles in all build configurations. The overlay view remains DEBUG-only.
@MainActor
public final class PerformanceOverlayModel: ObservableObject {
    public static let enabledDefaultsKey = "app.performance.overlay.enabled"
    @Published public var isVisible: Bool
    @Published public private(set) var lastAppLaunchDescription: String = "—"
    @Published public private(set) var launchToFirstUIDescription: String = "—"
    @Published public private(set) var launchToFirstWebViewDescription: String = "—"
    @Published public private(set) var lastTabRestoreDescription: String = "—"
    @Published public private(set) var lastMemoryPressureDescription: String = "—"
    @Published public private(set) var memoryMitigationDescription: String = "—"
    // MARK: - Rendering
    @Published public private(set) var liveWebViewsDescription: String = "—"
    @Published public private(set) var renderStateSummaryDescription: String = "—"
    // MARK: - WebView Lifecycle (DEBUG-only)
    @Published public private(set) var webViewCreateReuseDescription: String = "—"
    @Published public private(set) var attachToReadyDescription: String = "—"
    @Published public private(set) var attachToFirstPaintDescription: String = "—"
    @Published public private(set) var webViewPoolSnapshotDescription: String = "—"
    public var lastAppLaunchText: String { lastAppLaunchDescription }
    public var launchToFirstUIText: String { launchToFirstUIDescription }
    public var launchToFirstWebViewText: String { launchToFirstWebViewDescription }
    public var lastTabRestoreText: String { lastTabRestoreDescription }
    public var lastMemoryPressureText: String { lastMemoryPressureDescription }
    public var memoryMitigationText: String { memoryMitigationDescription }
    public var liveWebViewsText: String { liveWebViewsDescription }
    public var renderStateSummaryText: String { renderStateSummaryDescription }
    public var webViewCreateReuseText: String { webViewCreateReuseDescription }
    public var attachToReadyText: String { attachToReadyDescription }
    public var attachToFirstPaintText: String { attachToFirstPaintDescription }
    public var webViewPoolSnapshotText: String { webViewPoolSnapshotDescription }
    private var refreshTask: Task<Void, Never>?
    private var webViewPoolObserver: NSObjectProtocol?
    #if DEBUG
    private var webViewLifecycleCreateObserver: NSObjectProtocol?
    private var webViewLifecycleReuseObserver: NSObjectProtocol?
    private var debugWebViewCreatedCount: Int = 0
    private var debugWebViewReusedCount: Int = 0
    private struct RollingWindow {
        var values: [Double] = []
        let maxCount: Int
        init(maxCount: Int) {
            self.maxCount = max(1, maxCount)
        }
        mutating func append(_ value: Double) {
            values.append(value)
            if values.count > maxCount {
                values.removeFirst(values.count - maxCount)
            }
        }
        func p50() -> Double? {
            guard values.isEmpty == false else { return nil }
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
    }
    private var attachToReadyWindow = RollingWindow(maxCount: 20)
    private var attachToFirstPaintWindow = RollingWindow(maxCount: 20)
    private var lastAttachToReadySecondsByTabID: [UUID: Double] = [:]
    private var lastAttachToFirstPaintSecondsByTabID: [UUID: Double] = [:]
    #endif
    public init() {
        #if DEBUG
        if let value = UserDefaults.standard.object(forKey: Self.enabledDefaultsKey) as? Bool {
            self.isVisible = value
        } else {
            self.isVisible = false
        }
        #else
        // Overlay visibility isn't used in Release, but keep the property for API stability.
        self.isVisible = false
        #endif
    }
    public func toggle() {
        isVisible.toggle()
        UserDefaults.standard.set(isVisible, forKey: Self.enabledDefaultsKey)
        if isVisible {
            start()
        } else {
            stop()
        }
    }
    public func start() {
        guard refreshTask == nil else { return }
        if webViewPoolObserver == nil {
            webViewPoolObserver = NotificationCenter.default.addObserver(
                forName: WebViewPool.Notifications.didChange,
                object: nil,
                queue: nil
            ) { [weak self] note in
                let liveCount = (note.userInfo?["totalLiveCount"] as? Int) ?? (note.userInfo?["liveCount"] as? Int)
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Avoid publish-during-update cycles.
                    await Task.yield()
                    self.liveWebViewsDescription = liveCount.map { "\($0)" } ?? "—"
                }
            }
            // Seed with a best-effort immediate value.
            liveWebViewsDescription = "\(WebViewPool.totalLiveWebViewCount())"
        }
        refreshTask = Task { @MainActor in
            while Task.isCancelled == false {
                self.refreshFromTracerSnapshot()
                #if DEBUG
                await self.refreshWebViewPoolSnapshot()
                #endif
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        #if DEBUG
        startWebViewLifecycleObserversIfNeeded()
        #endif
    }
    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        if let token = webViewPoolObserver {
            NotificationCenter.default.removeObserver(token)
        }
        webViewPoolObserver = nil
        #if DEBUG
        stopWebViewLifecycleObservers()
        #endif
    }
    #if DEBUG
    private func refreshWebViewPoolSnapshot() async {
        let snapshots = await WebViewPool.debugAllPoolsSnapshot()
        guard snapshots.isEmpty == false else {
            webViewPoolSnapshotDescription = "—"
            return
        }
        // Keep it compact: one line per pool.
        let lines: [String] = snapshots
            .sorted(by: { $0.label < $1.label })
            .map { snap in
                let fg = snap.entriesByRecency.filter { $0.priority == .foreground }.count
                let bg = snap.entriesByRecency.filter { $0.priority == .background }.count
                let disc = snap.entriesByRecency.filter { $0.priority == .discarded }.count
                return "\(snap.label) live=\(snap.leasedCount + snap.idleCount)/\(snap.maxLiveWebViews) leased=\(snap.leasedCount) idle=\(snap.idleCount) pri(fg/bg/disc)=\(fg)/\(bg)/\(disc)"
            }
        webViewPoolSnapshotDescription = lines.joined(separator: " | ")
    }
    private func startWebViewLifecycleObserversIfNeeded() {
        if webViewLifecycleCreateObserver == nil {
            webViewLifecycleCreateObserver = NotificationCenter.default.addObserver(
                forName: WebViewLifecycleDebugNotifications.webViewCreated,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Avoid publish-during-update cycles.
                    await Task.yield()
                    self.debugWebViewCreatedCount += 1
                    self.updateWebViewCreateReuseText()
                }
            }
        }
        if webViewLifecycleReuseObserver == nil {
            webViewLifecycleReuseObserver = NotificationCenter.default.addObserver(
                forName: WebViewLifecycleDebugNotifications.webViewReused,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Avoid publish-during-update cycles.
                    await Task.yield()
                    self.debugWebViewReusedCount += 1
                    self.updateWebViewCreateReuseText()
                }
            }
        }
        updateWebViewCreateReuseText()
    }
    private func stopWebViewLifecycleObservers() {
        if let token = webViewLifecycleCreateObserver { NotificationCenter.default.removeObserver(token) }
        if let token = webViewLifecycleReuseObserver { NotificationCenter.default.removeObserver(token) }
        webViewLifecycleCreateObserver = nil
        webViewLifecycleReuseObserver = nil
    }
    private func updateWebViewCreateReuseText() {
        webViewCreateReuseDescription = "created=\(debugWebViewCreatedCount) reused=\(debugWebViewReusedCount)"
    }
    public func recordWebViewAttachToReady(tabID: UUID, seconds: Double) {
        let clamped = max(0, seconds)
        lastAttachToReadySecondsByTabID[tabID] = clamped
        attachToReadyWindow.append(clamped)
        let last = Self.formatSeconds(clamped)
        let p50 = attachToReadyWindow.p50().map { Self.formatSeconds($0) } ?? "—"
        attachToReadyDescription = "last=\(last) p50=\(p50)"
        Diagnostics.logDebug(
            "[Perf][WebView] attach→ready tabID=\(tabID.uuidString) dt=\(last)",
            subsystem: .runtime,
            category: "WebViewPerf"
        )
    }
    public func recordWebViewFirstPaintAfterAttach(tabID: UUID, seconds: Double) {
        let clamped = max(0, seconds)
        lastAttachToFirstPaintSecondsByTabID[tabID] = clamped
        attachToFirstPaintWindow.append(clamped)
        let last = Self.formatSeconds(clamped)
        let p50 = attachToFirstPaintWindow.p50().map { Self.formatSeconds($0) } ?? "—"
        attachToFirstPaintDescription = "last=\(last) p50=\(p50)"
        Diagnostics.logDebug(
            "[Perf][WebView] attach→firstPaint tabID=\(tabID.uuidString) dt=\(last)",
            subsystem: .runtime,
            category: "WebViewPerf"
        )
    }
    public func debugLastAttachToReadySeconds(tabID: UUID) -> Double? {
        lastAttachToReadySecondsByTabID[tabID]
    }
    public func debugLastAttachToFirstPaintSeconds(tabID: UUID) -> Double? {
        lastAttachToFirstPaintSecondsByTabID[tabID]
    }
    #else
    // Release builds: ensure zero behavior/overhead.
    public func recordWebViewAttachToReady(tabID: UUID, seconds: Double) {}
    public func recordWebViewFirstPaintAfterAttach(tabID: UUID, seconds: Double) {}
    public func debugLastAttachToReadySeconds(tabID: UUID) -> Double? { nil }
    public func debugLastAttachToFirstPaintSeconds(tabID: UUID) -> Double? { nil }
    #endif
    /// Push a human-readable render-state summary (e.g. from TabManager).
    public func setRenderStateSummary(_ summary: String) {
        renderStateSummaryDescription = summary.isEmpty ? "—" : summary
    }
    private func refreshFromTracerSnapshot() {
        let snapshot = PerformanceTracer.shared.snapshot()
        updateLaunch(snapshot: snapshot)
        updateTabRestore(snapshot: snapshot)
        updateMemoryPressure(snapshot: snapshot)
    }
    private func updateLaunch(snapshot: (active: [PerformanceTracer.Trace], completed: [PerformanceTracer.Trace], instants: [PerformanceTracer.InstantEvent])) {
        let appLaunchName = SafariPerformanceMetricName.appLaunch.name
        let firstUIName = SafariPerformanceMetricName.firstUIRendered.name
        let firstWebViewName = SafariPerformanceMetricName.firstWebViewReady.name
        let allLaunchTraces = snapshot.completed.filter { $0.name == appLaunchName }
        let lastLaunch = allLaunchTraces.max(by: { ($0.endTimeNanos ?? 0) < ($1.endTimeNanos ?? 0) })
        if let lastLaunch, let durationNanos = lastLaunch.durationNanos {
            lastAppLaunchDescription = Self.formatSeconds(Double(durationNanos) / 1_000_000_000)
            let start = lastLaunch.startTimeNanos
            let end = lastLaunch.endTimeNanos ?? (start &+ durationNanos)
            if let firstUI = snapshot.instants
                .filter({ $0.name == firstUIName && $0.timeNanos >= start && $0.timeNanos <= end })
                .min(by: { $0.timeNanos < $1.timeNanos })
            {
                launchToFirstUIDescription = Self.formatSeconds(Double(firstUI.timeNanos &- start) / 1_000_000_000)
            } else {
                launchToFirstUIDescription = "—"
            }
            if let firstWebView = snapshot.instants
                .filter({ $0.name == firstWebViewName && $0.timeNanos >= start && $0.timeNanos <= end })
                .min(by: { $0.timeNanos < $1.timeNanos })
            {
                launchToFirstWebViewDescription = Self.formatSeconds(Double(firstWebView.timeNanos &- start) / 1_000_000_000)
            } else {
                launchToFirstWebViewDescription = "—"
            }
        } else {
            lastAppLaunchDescription = "—"
            launchToFirstUIDescription = "—"
            launchToFirstWebViewDescription = "—"
        }
    }
    private func updateTabRestore(snapshot: (active: [PerformanceTracer.Trace], completed: [PerformanceTracer.Trace], instants: [PerformanceTracer.InstantEvent])) {
        let transitionName = SafariPerformanceMetricName.tabLifecycleTransition.name
        // Treat discarded→active transition as "restore".
        let restoreCandidates = snapshot.completed
            .filter { trace in
                guard trace.name == transitionName else { return false }
                return trace.metadata["from"] == "discarded" && trace.metadata["to"] == "active"
            }
        if let lastRestore = restoreCandidates.max(by: { ($0.endTimeNanos ?? 0) < ($1.endTimeNanos ?? 0) }),
           let durationNanos = lastRestore.durationNanos
        {
            lastTabRestoreDescription = Self.formatSeconds(Double(durationNanos) / 1_000_000_000)
        } else {
            lastTabRestoreDescription = "—"
        }
    }
    private func updateMemoryPressure(snapshot: (active: [PerformanceTracer.Trace], completed: [PerformanceTracer.Trace], instants: [PerformanceTracer.InstantEvent])) {
        let receivedName = SafariPerformanceMetricName.memoryPressureReceived.name
        let stableName = SafariPerformanceMetricName.memoryPressureStable.name
        let mitigationName = SafariPerformanceMetricName.memoryPressureMitigation.name
        if let lastReceived = snapshot.instants
            .filter({ $0.name == receivedName })
            .max(by: { $0.timeNanos < $1.timeNanos })
        {
            let level = lastReceived.metadata["level"] ?? "?"
            lastMemoryPressureDescription = "level=\(level)"
        } else {
            lastMemoryPressureDescription = "—"
        }
        if let activeMitigation = snapshot.active
            .filter({ $0.name == mitigationName })
            .max(by: { $0.startTimeNanos < $1.startTimeNanos })
        {
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds &- activeMitigation.startTimeNanos) / 1_000_000_000
            memoryMitigationDescription = "active \(Self.formatSeconds(elapsed))"
            return
        }
        if let lastMitigation = snapshot.completed
            .filter({ $0.name == mitigationName })
            .max(by: { ($0.endTimeNanos ?? 0) < ($1.endTimeNanos ?? 0) }),
           let durationNanos = lastMitigation.durationNanos
        {
            var desc = "last \(Self.formatSeconds(Double(durationNanos) / 1_000_000_000))"
            if snapshot.instants.contains(where: { $0.name == stableName }) {
                // No extra data today; keep as a hint the stable signal exists.
                desc += " (stable)"
            }
            memoryMitigationDescription = desc
        } else {
            memoryMitigationDescription = "—"
        }
    }
    private static func formatSeconds(_ seconds: Double) -> String {
        if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        }
        return String(format: "%.2fs", seconds)
    }
}

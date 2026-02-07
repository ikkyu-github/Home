import Foundation
import Combine
import SafariLikeCoreKit
import os
/// Owns attachment state and drives it from reality snapshots.
///
/// State machine definition: see Docs/ATTACHMENT_STATE_MACHINE.md.
///
/// Responsibilities:
/// - `WebViewAttachmentState` transitions (especially `.attaching` / `.ready` / `.timedOut`)
/// - Observing `TabWebStore.webViewReality` and `uxRestoreController.state`
/// - Starting/cancelling timeout timers via `WatchdogController`
///
/// Non-responsibilities:
/// - No UI access
/// - No WKWebView access
@MainActor
final class AttachmentCoordinator {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "AttachmentCoordinator")
    /// Pure helper for tests/diagnostics.
    static func isInvariantViolation(snapshotIsRealityReady: Bool, attachmentState: WebViewAttachmentState) -> Bool {
        guard snapshotIsRealityReady else { return false }
        if case .timedOut = attachmentState { return true }
        return false
    }
    struct IO {
        let tabID: UUID
        let snapshotDataForRestoreUX: @MainActor () -> Data?
        let hasWebViewHandle: @MainActor () -> Bool
        let requestRuntimeActivate: @MainActor () async -> Void
        let requestUIRerender: @MainActor () -> Void
        let applyWebsitePreferencesForActiveHost: @MainActor () -> Void
        #if DEBUG
        let recordWebViewAttachToReady: @MainActor (_ tabID: UUID, _ seconds: Double) -> Void
        #endif
    }

    private struct AttachmentRecord {
        var generation: UInt64
        var state: WebViewAttachmentState
        var updatedAt: Date
        var lastEmittedState: WebViewAttachmentState?
        var lastSoftRecoverAt: Date?
    }

    private let watchdog: WatchdogController
    private var realityCancellables: [UUID: AnyCancellable] = [:]
    private var restoreCancellables: [UUID: AnyCancellable] = [:]
    private var latestRealityByTabID: [UUID: WebViewRealitySnapshot] = [:]
    private var attachmentByTabID: [UUID: AttachmentRecord] = [:]
    private var ioByTabID: [UUID: IO] = [:]
    private var activeTabID: UUID?
    private let statusSink: (@MainActor (WebViewAttachmentStatus?) -> Void)

    private let maxAttachedWebViews: Int
    #if DEBUG
    private var attachStartNanosByTabID: [UUID: UInt64] = [:]
    #endif
    /// Safari-like: a periodic self-healing reconcile loop.
    private var reconciliationTickerTask: Task<Void, Never>?
    private var isAppActive: Bool = true
    init(
        watchdog: WatchdogController,
        maxAttachedWebViews: Int = BrowserPolicy.maxConcurrentViews,
        statusSink: @escaping @MainActor (WebViewAttachmentStatus?) -> Void
    ) {
        self.watchdog = watchdog
        self.maxAttachedWebViews = max(1, maxAttachedWebViews)
        self.statusSink = statusSink
    }
    func setAppIsActive(_ isActive: Bool) {
        isAppActive = isActive
        if isActive == false {
            reconciliationTickerTask?.cancel()
            reconciliationTickerTask = nil
            for tabID in latestRealityByTabID.keys {
                watchdog.cancelAttachmentTimeout(tabID: tabID)
            }
        }
    }
    func shutdown() {
        watchdog.cancelAll()
        reconciliationTickerTask?.cancel()
        reconciliationTickerTask = nil
        for tabID in Set(realityCancellables.keys) {
            realityCancellables[tabID]?.cancel()
            realityCancellables[tabID] = nil
            restoreCancellables[tabID]?.cancel()
            restoreCancellables[tabID] = nil
            latestRealityByTabID[tabID] = nil
            attachmentByTabID[tabID] = nil
            ioByTabID[tabID] = nil
        }
        activeTabID = nil
    }
    func startTrackingIfNeeded(tabID: UUID, store: any WebViewRealityObserving, io: IO) {
        ioByTabID[tabID] = io
        if realityCancellables[tabID] == nil {
            realityCancellables[tabID] = store.webViewRealityPublisher
                .compactMap { $0 }
                .sink { [weak self] snapshot in
                    guard let self else { return }
                    Task { @MainActor in
                        // Avoid publish-during-update cycles.
                        await Task.yield()
                        self.onRealitySnapshot(tabID: tabID, snapshot: snapshot, io: io)
                    }
                }
        }
        if restoreCancellables[tabID] == nil {
            restoreCancellables[tabID] = store.uxRestoreStatePublisher
                .sink { [weak self] state in
                    guard let self else { return }
                    Task { @MainActor in
                        // Avoid publish-during-update cycles.
                        await Task.yield()
                        self.onRestoreState(tabID: tabID, state: state, io: io)
                    }
                }
        }
    }
    func stopTracking(tabID: UUID) {
        realityCancellables[tabID]?.cancel()
        realityCancellables[tabID] = nil
        restoreCancellables[tabID]?.cancel()
        restoreCancellables[tabID] = nil
        latestRealityByTabID[tabID] = nil
        attachmentByTabID[tabID] = nil
        ioByTabID[tabID] = nil
        watchdog.cancelAttachmentTimeout(tabID: tabID)
        #if DEBUG
        attachStartNanosByTabID[tabID] = nil
        #endif
        if activeTabID == tabID {
            activeTabID = nil
            statusSink(nil)
        }
    }
    // MARK: - Events
    func onRootViewAppeared(initialTabRequiresWebView: Bool, io: IO) {
        activeTabID = io.tabID
        if initialTabRequiresWebView {
            setAttaching(io: io, reason: "rootViewAppeared")
        } else {
            setReady(io: io, reason: "rootViewAppeared")
        }
        #if DEBUG
        debugValidateAttachedBudget(reason: "rootViewAppeared")
        #endif
        ensureReconciliationTickerRunningIfNeeded()
    }
    func onTabActivated(tabRequiresWebView: Bool, io: IO) {
        activeTabID = io.tabID
        if tabRequiresWebView {
            setAttaching(io: io, reason: "tabActivated")
        } else {
            setReady(io: io, reason: "tabActivated")
        }
        #if DEBUG
        debugValidateAttachedBudget(reason: "tabActivated")
        #endif
        ensureReconciliationTickerRunningIfNeeded()
    }
    func onWebViewAttached(io: IO) {
        // Prefer snapshot-driven transitions; this acts as a hint only.
        #if DEBUG
        debugValidateAttachedBudget(reason: "webViewAttached")
        #endif
        ensureReconciliationTickerRunningIfNeeded()
    }
    func onWebViewDetached(tabRequiresWebView: Bool, io: IO) {
        // Safari-like: a deliberate detach (e.g. pane off-screen, discard, budget demotion)
        // must not trigger watchdog timeouts or user-visible attachment errors.
        // We return to idle until the UI provides a handle again.
        setIdle(io: io, reason: "webViewDetached")
        watchdog.cancelAttachmentTimeout(tabID: io.tabID)
        #if DEBUG
        attachStartNanosByTabID[io.tabID] = nil
        debugValidateAttachedBudget(reason: "webViewDetached")
        #endif
    }

    #if DEBUG
    private func debugValidateAttachedBudget(reason: String) {
        // AttachmentCoordinator has no WKWebView access by design.
        // We treat "attached" as "UI currently reports it has a WebView handle".
        let attached = ioByTabID
            .filter { _, io in io.hasWebViewHandle() }
            .map { $0.key }
            .sorted(by: { $0.uuidString < $1.uuidString })

        if attached.count > maxAttachedWebViews {
            assertionFailure(
                "[AttachmentCoordinator] attached web views exceeded budget. attached=\(attached.count) max=\(maxAttachedWebViews) activeTabID=\(activeTabID?.uuidString ?? "<nil>") reason=\(reason) tabs=\(attached.map { $0.uuidString.prefix(8) }.joined(separator: ","))"
            )
        }
    }
    #endif
    func requestReconcile(tabID: UUID, io: IO, reason: String) {
        if let snapshot = latestRealityByTabID[tabID] {
            onRealitySnapshot(tabID: tabID, snapshot: snapshot, io: io)
        } else {
            // No snapshot yet; best-effort: if there's no handle, attempt soft recovery.
            Task { @MainActor in
                await softRecoverIfNeeded(io: io, reason: reason)
            }
        }
    }

    /// Runtime escape hatch: request an explicit state transition for diagnostics/recovery.
    /// Single-writer rule: callers request; coordinator applies.
    func requestRuntimeStateOverride(tabID: UUID, desired: WebViewAttachmentState) {
        guard let io = ioByTabID[tabID] else { return }
        switch desired {
        case .idle:
            setIdle(io: io, reason: "runtimeOverride")
        case .attaching:
            setAttaching(io: io, reason: "runtimeOverride")
        case .ready:
            setReady(io: io, reason: "runtimeOverride")
        case .restoring(let snapshot):
            setState(tabID: tabID, state: .restoring(snapshot: snapshot), bumpGeneration: false)
        case .timedOut:
            setState(tabID: tabID, state: .timedOut, bumpGeneration: false)
        case .failed(let reason):
            setState(tabID: tabID, state: .failed(reason: reason), bumpGeneration: false)
        }
    }
    // MARK: - Snapshot-driven reconcile
    private func onRealitySnapshot(tabID: UUID, snapshot: WebViewRealitySnapshot, io: IO) {
        guard snapshot.tabID == tabID else { return }
        latestRealityByTabID[tabID] = snapshot
        guard snapshot.isRealityReady else {
            // Snapshot says not ready: do not force downgrades.
            return
        }

        // Snapshot may claim reality is ready, but the UI might not currently have a usable handle
        // (e.g. rotation detach/reattach). Only allow ready when both are true.
        if io.hasWebViewHandle() == false {
            #if DEBUG
            Self.logger.debug(
                "reality_ready_but_handle_missing tabID=\(io.tabID.uuidString, privacy: .public)"
            )
            #endif

            // Keep attachment progressing until a handle exists.
            setAttaching(io: io, reason: "reality_ready_but_handle_missing")

            // Best-effort: attempt to recover by requesting runtime activation and UI rerender.
            // Do NOT recurse; the periodic ticker will re-reconcile.
            Task { @MainActor in
                await softRecoverIfNeeded(io: io, reason: "reality_ready_but_handle_missing")
            }
            return
        }

        // Snapshot is authoritative only when the UI has a handle: force ready and cancel watchdog.
        setReady(io: io, reason: "realitySnapshot")
    }
    private func onRestoreState(tabID: UUID, state: UXRestoreController.State, io: IO) {
        switch state {
        case .restoring:
            setState(tabID: tabID, state: .restoring(snapshot: io.snapshotDataForRestoreUX()), bumpGeneration: false)
        case .timedOut:
            // Treat UX restore timeouts as non-fatal; avoid user-visible attachment errors.
            // Reality snapshots can still promote to ready later.
            setIdle(io: io, reason: "uxRestore.timedOut")
            watchdog.cancelAttachmentTimeout(tabID: io.tabID)
        case .idle, .completed:
            // Restore finished: if we have a handle, go ready; else return to attaching.
            if io.hasWebViewHandle() {
                setReady(io: io, reason: "uxRestore.completed")
            } else {
                setAttaching(io: io, reason: "uxRestore.completed.noHandle")
            }
        @unknown default:
            if io.hasWebViewHandle() {
                setReady(io: io, reason: "uxRestore.unknown")
            } else {
                setAttaching(io: io, reason: "uxRestore.unknown.noHandle")
            }
        }
    }
    // MARK: - State transitions
    private func currentRecord(tabID: UUID) -> AttachmentRecord {
        if let existing = attachmentByTabID[tabID] {
            return existing
        }
        let initial = AttachmentRecord(generation: 0, state: .idle, updatedAt: .distantPast, lastEmittedState: nil, lastSoftRecoverAt: nil)
        attachmentByTabID[tabID] = initial
        return initial
    }

    private func setState(tabID: UUID, state: WebViewAttachmentState, bumpGeneration: Bool) {
        var record = currentRecord(tabID: tabID)
        if bumpGeneration {
            record.generation &+= 1
        }
        // Idempotent: do nothing for equivalent state updates.
        if Self.equivalentState(record.state, state) {
            return
        }
        record.state = state
        record.updatedAt = Date()
        attachmentByTabID[tabID] = record
        emitStatusIfChanged(tabID: tabID)
    }

    private func setIdle(io: IO, reason: String) {
        let existing = currentRecord(tabID: io.tabID)
        if case .idle = existing.state {
            watchdog.cancelAttachmentTimeout(tabID: io.tabID)
            _ = reason
            return
        }
        setState(tabID: io.tabID, state: .idle, bumpGeneration: true)
        watchdog.cancelAttachmentTimeout(tabID: io.tabID)
        _ = reason
    }

    private func setAttaching(io: IO, reason: String) {
        let existing = currentRecord(tabID: io.tabID)
        if case .attaching = existing.state {
            _ = reason
            return
        }
        // Bump generation: a new attach attempt cancels/invalidates prior async work.
        setState(tabID: io.tabID, state: .attaching, bumpGeneration: true)
        let gen = attachmentByTabID[io.tabID]?.generation ?? 0
        #if DEBUG
        attachStartNanosByTabID[io.tabID] = DispatchTime.now().uptimeNanoseconds
        #endif
        watchdog.startAttachmentTimeout(
            tabID: io.tabID,
            timeoutSeconds: 12.0,
            onTimeout: { [weak self] tabID in
                guard let self else { return }
                Task { @MainActor in
                    await self.onAttachmentTimeout(tabID: tabID, expectedGeneration: gen, io: io)
                }
            }
        )
        _ = reason // reserved for future structured logging
    }
    private func setReady(io: IO, reason: String) {
        setState(tabID: io.tabID, state: .ready, bumpGeneration: false)
        watchdog.cancelAttachmentTimeout(tabID: io.tabID)
        io.applyWebsitePreferencesForActiveHost()
        #if DEBUG
        if let start = attachStartNanosByTabID[io.tabID] {
            let end = DispatchTime.now().uptimeNanoseconds
            let seconds = Double(end &- start) / 1_000_000_000
            io.recordWebViewAttachToReady(io.tabID, seconds)
            attachStartNanosByTabID[io.tabID] = nil
        }
        #endif
        _ = reason
    }
    private func onAttachmentTimeout(tabID: UUID, expectedGeneration: UInt64, io: IO) async {
        guard io.tabID == tabID else { return }
        guard let record = attachmentByTabID[tabID], record.generation == expectedGeneration else { return }
        guard case .attaching = record.state else { return }
        // Last chance: if reality is already ready, become ready and exit.
        if let snapshot = latestRealityByTabID[tabID], snapshot.isRealityReady {
            setReady(io: io, reason: "watchdog.timeout.realityReady")
            return
        }
        // Best-effort soft recovery: if missing handle, try to activate runtime and rerender.
        await softRecoverIfNeeded(io: io, reason: "watchdog.timeout")
        // Give the system a moment to publish a snapshot after activation.
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard let record2 = attachmentByTabID[tabID], record2.generation == expectedGeneration else { return }
        if let snapshot = latestRealityByTabID[tabID], snapshot.isRealityReady {
            setReady(io: io, reason: "watchdog.timeout.postRecover.realityReady")
            return
        }
        // Escape hatch: timed out.
        setState(tabID: tabID, state: .timedOut, bumpGeneration: false)
    }
    private func softRecoverIfNeeded(io: IO, reason: String) async {
        guard io.hasWebViewHandle() == false else { return }
        var record = currentRecord(tabID: io.tabID)
        let now = Date()
        if let last = record.lastSoftRecoverAt, now.timeIntervalSince(last) < 0.5 {
            return
        }
        record.lastSoftRecoverAt = now
        attachmentByTabID[io.tabID] = record
        await io.requestRuntimeActivate()
        io.requestUIRerender()
        _ = reason
    }
    // MARK: - Self-healing ticker
    private func ensureReconciliationTickerRunningIfNeeded() {
        guard isAppActive else { return }
        guard reconciliationTickerTask == nil else { return }
        reconciliationTickerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let tickIntervalNs: UInt64 = 250_000_000
            let stableReadyTicksToStop = 6
            var stableReadyTicks = 0
            var lastObservedTabID: UUID?
            var lastObservedStateDescription: String?
            defer {
                self.reconciliationTickerTask = nil
            }
            while Task.isCancelled == false {
                guard let tabID = self.activeTabID,
                      let io = self.ioByTabID[tabID]
                else { break }
                let record = self.currentRecord(tabID: tabID)
                let stateDescription = String(describing: record.state)
                if lastObservedTabID != tabID || lastObservedStateDescription != stateDescription {
                    stableReadyTicks = 0
                    lastObservedTabID = tabID
                    lastObservedStateDescription = stateDescription
                }
                // Reconcile using the latest captured snapshot.
                self.requestReconcile(tabID: tabID, io: io, reason: "ticker")
                if case .ready = record.state {
                    stableReadyTicks += 1
                    if stableReadyTicks >= stableReadyTicksToStop {
                        break
                    }
                } else {
                    stableReadyTicks = 0
                }
                do {
                    try await Task.sleep(nanoseconds: tickIntervalNs)
                } catch {
                    break
                }
            }
            self.reconciliationTickerTask = nil
        }
    }

    private static func equivalentState(_ lhs: WebViewAttachmentState, _ rhs: WebViewAttachmentState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.attaching, .attaching), (.ready, .ready), (.timedOut, .timedOut):
            return true
        case (.restoring, .restoring):
            // Snapshot bytes are not user-visible; treat as equivalent.
            return true
        case (.failed(let l), .failed(let r)):
            return l == r
        default:
            return false
        }
    }

    private func emitStatusIfChanged(tabID: UUID) {
        // Defer to avoid publish-during-update cycles.
        // Re-read after yielding so outdated tasks cannot publish stale state.
        Task { @MainActor in
            await Task.yield()
            guard var record = self.attachmentByTabID[tabID] else { return }
            if let last = record.lastEmittedState, Self.equivalentState(last, record.state) {
                return
            }
            record.lastEmittedState = record.state
            self.attachmentByTabID[tabID] = record
            self.statusSink(WebViewAttachmentStatus(tabID: tabID, state: record.state, updatedAt: record.updatedAt))
        }
    }
}

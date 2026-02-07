import Foundation
import SafariLikeCoreKit

@MainActor
final class TabRestoreController {
    private unowned let manager: TabManager

    // MARK: - Session Restore Tracing
    private var sessionRestoreTraceID: PerformanceTracer.TraceID?
    private var didMarkSessionRestorePhaseAUIReady: Bool = false
    private var didMarkSessionRestorePhaseBFirstWebReady: Bool = false
    private var sessionRestoreInteractiveTabIDs: Set<UUID> = []

    init(manager: TabManager) {
        self.manager = manager
    }

    // MARK: - Restore orchestration
    func endSessionRestoreAndActivateVisiblePanesIfNeeded() {
        guard manager.hasActivatedInitialVisiblePanes == false else { return }
        manager.hasActivatedInitialVisiblePanes = true
        manager.isPerformingSessionRestore = false

        if manager.currentSessionStore.selectedTabID == nil {
            if let existing = manager.currentSessionStore.tabs.first?.id {
                manager.currentSessionStore.selectTab(id: existing)
                manager.activeTabID = existing
            }
        }

        guard let selected = manager.currentSessionStore.selectedTabID else { return }
        if manager.isSplitViewEnabled {
            let existingCompanion: UUID? = {
                if let leftTabID = manager.leftTabID, leftTabID != selected { return leftTabID }
                if let rightTabID = manager.rightTabID, rightTabID != selected { return rightTabID }
                return manager.currentSessionStore.tabs.first(where: { $0.id != selected })?.id
            }()

            if manager.activePane == .right {
                manager.rightTabID = selected
                manager.leftTabID = existingCompanion
            } else {
                manager.leftTabID = selected
                manager.rightTabID = existingCompanion
            }
            if manager.leftTabID == manager.rightTabID { manager.rightTabID = nil }

            if let leftTabID = manager.leftTabID { manager.assignTab(leftTabID, to: .primary) }
            if let rightTabID = manager.rightTabID { manager.assignTab(rightTabID, to: .secondary) }

            // Do not attach WKWebViews directly from restore logic.
            // Attachment decisions are owned by CoreKit lifecycle + budget reconciliation.
            manager.lifecycleController.applyRenderBudget(reason: "sessionRestore.end")
        } else {
            // Do not attach WKWebViews directly from restore logic.
            manager.lifecycleController.applyRenderBudget(reason: "sessionRestore.end")
        }

        let totalActiveWebViews = manager.normalTabRegistry.activeWebViewsCount + manager.privateTabRegistry.activeWebViewsCount
        if totalActiveWebViews > 2 {
            Diagnostics.logError(
                "Session restore exceeded 2-view budget: activeWebViewsCount=\(totalActiveWebViews)",
                subsystem: .runtime,
                category: "SessionRestore"
            )
            assertionFailure("Session restore exceeded 2-view budget")
        }

        Task { @MainActor [weak manager] in
            guard let manager else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            manager.prewarmHeuristicsCandidatesIfNeeded()
        }
    }

    func applyRestoredSplitTabIDs(_ ids: [UUID]) {
        manager.leftTabID = ids.first
        if ids.count >= 2 { manager.rightTabID = ids.last } else { manager.rightTabID = nil }
        if let leftTabID = manager.leftTabID { manager.assignTab(leftTabID, to: .primary) }
        if let rightTabID = manager.rightTabID { manager.assignTab(rightTabID, to: .secondary) }
    }

    // MARK: - Session Restore Tracing
    var isSessionRestoreInProgress: Bool { sessionRestoreTraceID != nil }

    func isTabJSInteractive(_ tabID: UUID) -> Bool {
        sessionRestoreInteractiveTabIDs.contains(tabID)
    }

    func beginSessionRestoreTracingIfNeeded(sceneID: String) {
        guard sessionRestoreTraceID == nil else { return }
        sessionRestoreTraceID = PerformanceTracer.shared.startTrace(.sessionRestoreTotal, metadata: ["sceneID": sceneID])
        didMarkSessionRestorePhaseAUIReady = false
        didMarkSessionRestorePhaseBFirstWebReady = false
        sessionRestoreInteractiveTabIDs.removeAll(keepingCapacity: true)
    }

    func markSessionRestorePhaseAUIReady(source: String) {
        guard sessionRestoreTraceID != nil else { return }
        guard didMarkSessionRestorePhaseAUIReady == false else { return }
        didMarkSessionRestorePhaseAUIReady = true
        PerformanceTracer.shared.instantEvent(.sessionRestorePhaseAUIReady, metadata: ["source": source])
    }

    func markSessionRestorePhaseBFirstWebReadyIfNeeded(tabID: UUID) {
        guard sessionRestoreTraceID != nil else { return }
        guard didMarkSessionRestorePhaseBFirstWebReady == false else { return }
        didMarkSessionRestorePhaseBFirstWebReady = true
        PerformanceTracer.shared.instantEvent(.sessionRestorePhaseBFirstWebReady, metadata: ["tabID": tabID.uuidString])
    }

    func markSessionRestoreTabInteractive(tabID: UUID) {
        guard sessionRestoreTraceID != nil else { return }
        sessionRestoreInteractiveTabIDs.insert(tabID)
    }

    func maybeEndSessionRestoreTraceIfSatisfied() {
        guard let id = sessionRestoreTraceID else { return }
        guard isSelectedTabInteractive() else { return }
        guard areVisiblePanesLive() else { return }

        PerformanceTracer.shared.endTrace(id)
        sessionRestoreTraceID = nil
        didMarkSessionRestorePhaseAUIReady = false
        didMarkSessionRestorePhaseBFirstWebReady = false
        sessionRestoreInteractiveTabIDs.removeAll(keepingCapacity: false)
    }

    private func areVisiblePanesLive() -> Bool {
        let ids = manager.currentVisiblePaneTabIDs()
        guard ids.isEmpty == false else { return false }
        for id in ids {
            guard manager.state.tabs.first(where: { $0.id == id })?.runtimeAttachment == .attached else { return false }
        }
        return true
    }

    private func isSelectedTabInteractive() -> Bool {
        guard let selected = manager.currentSessionStore.selectedTabID else { return false }
        return sessionRestoreInteractiveTabIDs.contains(selected)
    }
}

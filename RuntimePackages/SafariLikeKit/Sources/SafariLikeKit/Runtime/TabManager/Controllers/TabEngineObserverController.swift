import Foundation
import SafariLikeCoreKit

@MainActor
final class TabEngineObserverController {
    private unowned let manager: TabManager

    private var engineInteractiveObserverToken: UUID?
    private var engineProcessTerminationObserverToken: UUID?
    private var memoryPressureResponder: MemoryPressureResponder?
    private var memoryPressureMitigationTraceID: UUID?

    init(manager: TabManager) {
        self.manager = manager
    }

    func startObserving(initialActiveTabID: UUID) {
        engineInteractiveObserverToken = EngineController.shared.addWebViewInteractiveObserver { [weak manager] tabID in
            guard let manager else { return }
            manager.lifecycleTransitionTracing.markJSInteractive(tabID: tabID)
            manager.markSessionRestoreTabInteractive(tabID: tabID)
            manager.maybeEndSessionRestoreTraceIfSatisfied()
        }

        engineProcessTerminationObserverToken = EngineController.shared.addWebContentProcessTerminationObserver { [weak self] tabID in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard let siteKey = self.siteKeyForHeuristics(tabID: tabID) else { return }
                await SiteHeuristicsRuntime.collector.recordCrash(siteKey: siteKey)
            }
        }

        memoryPressureResponder = MemoryPressureResponder(tabManager: manager)
        memoryPressureResponder?.start()

        _ = initialActiveTabID
    }

    func stopObserving() async {
        if let token = engineInteractiveObserverToken {
            EngineController.shared.removeWebViewInteractiveObserver(token)
            engineInteractiveObserverToken = nil
        }
        if let token = engineProcessTerminationObserverToken {
            EngineController.shared.removeWebContentProcessTerminationObserver(token)
            engineProcessTerminationObserverToken = nil
        }

        memoryPressureResponder?.stop()
        memoryPressureResponder = nil

        if let id = memoryPressureMitigationTraceID {
            PerformanceTracer.shared.endTrace(id)
            memoryPressureMitigationTraceID = nil
        }
    }

    func handleMemoryPressureEvent(_ event: EngineController.MemoryPressureEvent) {
        switch event {
        case .received(let level):
            PerformanceTracer.shared.instantEvent(
                .memoryPressureReceived,
                metadata: ["level": String(describing: level)]
            )
            if memoryPressureMitigationTraceID == nil {
                memoryPressureMitigationTraceID = PerformanceTracer.shared.startTrace(
                    .memoryPressureMitigation,
                    metadata: ["level": String(describing: level)]
                )
            }
            switch level {
            case .warning:
                manager.discardController.apply(trigger: .memoryWarning(.warning))
            case .critical:
                manager.discardController.apply(trigger: .memoryWarning(.critical))
                manager.discardController.apply(trigger: .thermalState(.critical))
            @unknown default:
                manager.discardController.apply(trigger: .memoryWarning(.warning))
            }

            // Best-effort per-site correlation: attribute memory pressure to visible panes.
            let score: Int = (level == .critical) ? 90 : 70
            var visible: Set<UUID> = Set(manager.currentVisiblePaneTabIDs())
            if let selected = manager.sessionStore.selectedTabID { visible.insert(selected) }
            for tabID in visible {
                if let siteKey = siteKeyForHeuristics(tabID: tabID) {
                    Task {
                        await SiteHeuristicsRuntime.collector.recordMemoryPressure(siteKey: siteKey, score: score)
                    }
                }
            }

        case .mitigationStarted:
            if memoryPressureMitigationTraceID == nil {
                memoryPressureMitigationTraceID = PerformanceTracer.shared.startTrace(.memoryPressureMitigation)
            }
            manager.discardController.apply(trigger: .memoryWarning(.warning))

        case .step(let step):
            switch step {
            case .freezeTab(let tabID):
                PerformanceTracer.shared.instantEvent(
                    .memoryPressureFreezeTab,
                    metadata: ["tabID": tabID.uuidString]
                )
                if let siteKey = siteKeyForHeuristics(tabID: tabID) {
                    Task {
                        await SiteHeuristicsRuntime.collector.recordMemoryPressure(siteKey: siteKey, score: 80)
                    }
                }

            case .evictTab(let tabID):
                PerformanceTracer.shared.instantEvent(
                    .memoryPressureEvictTab,
                    metadata: ["tabID": tabID.uuidString]
                )
                if let siteKey = siteKeyForHeuristics(tabID: tabID) {
                    Task {
                        await SiteHeuristicsRuntime.collector.recordMemoryPressure(siteKey: siteKey, score: 90)
                    }
                }

            case .releaseWebView(let tabID, let reason):
                PerformanceTracer.shared.instantEvent(
                    .memoryPressureReleaseWebView,
                    metadata: [
                        "tabID": tabID.uuidString,
                        "reason": String(describing: reason)
                    ]
                )
                if let siteKey = siteKeyForHeuristics(tabID: tabID) {
                    Task {
                        await SiteHeuristicsRuntime.collector.recordMemoryPressure(siteKey: siteKey, score: 75)
                    }
                }

            @unknown default:
                break
            }

        case .stable:
            PerformanceTracer.shared.instantEvent(.memoryPressureStable)
            if let id = memoryPressureMitigationTraceID {
                PerformanceTracer.shared.endTrace(id)
                memoryPressureMitigationTraceID = nil
            }

        @unknown default:
            manager.discardController.apply(trigger: .memoryWarning(.warning))
        }
    }

    private func siteKeyForHeuristics(tabID: UUID) -> String? {
        guard let urlString = manager.sessionStore.tabs.first(where: { $0.id == tabID })?.urlString,
              let url = URL(string: urlString) else {
            return nil
        }
        return SiteHeuristicsModel.normalizeSiteKey(from: url)
    }
}

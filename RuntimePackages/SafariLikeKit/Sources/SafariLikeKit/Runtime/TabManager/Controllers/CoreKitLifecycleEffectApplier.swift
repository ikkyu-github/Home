import Foundation
import SafariLikeCoreKit

@MainActor
enum CoreKitLifecycleEffectApplier {
    static func apply(
        _ effects: [SafariLikeCoreKit.TabPageLifecycleStateMachine.Effect],
        manager: TabManager
    ) {
        for effect in effects {
            switch effect {
            case .activate(let tabID, let protected, let why):
                guard manager.isPerformingSessionRestore == false else { continue }
                guard manager.state.isTabOverviewVisible == false else { continue }
                guard let store = manager.currentTabRegistry.existingStore(for: tabID) else { continue }
                guard store.webViewHandle == nil else { continue }

                manager.tabTasks.replaceTask(tabID: tabID, key: .renderBudgetActivate) {
                    Task { @MainActor [weak manager] in
                        guard let manager else { return }
                        let webTx = manager.beginWebViewTransition(reason: "core.activate.\(why)", tabID: tabID)
                        _ = await manager.activateRuntimeStore(
                            tabID: tabID,
                            protectedTabIDs: protected,
                            token: webTx,
                            reason: "core.activate.\(why)"
                        )
                        if Task.isCancelled { return }
                        RuntimeMetrics.shared.increment(.webViewActivated)
                    }
                }

            case .deactivateToSnapshotOnly(let tabID, let why):
                manager.renderController(for: tabID).enterSnapshotOnly(reason: "core.snapshotOnly.\(why)")

            case .suspend(let tabID, let why):
                manager.requestDeactivateWebView(tabID: tabID, mode: .cold, reason: "core.suspend.\(why)")
            @unknown default:
                continue // fallback: safe default
            }
        }
    }
}

import Foundation
import SafariLikeCoreKit
@MainActor
final class TabDiscardController {
    weak var tabManager: TabManager?
    var task: Task<Void, Never>?
    private let discardConfig: SafariLikeCoreKit.TabDiscardConfig
    init(tabManager: TabManager? = nil, discardConfig: SafariLikeCoreKit.TabDiscardConfig = .default) {
        self.tabManager = tabManager
        self.discardConfig = discardConfig
    }
    func start() {
        task?.cancel()
        task = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                await self.applyTabDiscardPolicyIfNeeded()
                do {
                    let seconds = max(1, self.discardConfig.sweepInterval)
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }
    func stop() {
        task?.cancel()
        task = nil
    }
    func protectedTabIDsForActivePanes() -> Set<UUID> {
        guard let tabManager else { return [] }
        var protected = Set(tabManager.currentVisiblePaneTabIDs())
        // Always protect whichever tab is currently being bound/bound.
        switch tabManager.activeBindingState {
        case .bound(let id), .binding(let id):
            protected.insert(id)
        case .unbound, .unbinding:
            break
        }
        return protected
    }
    func applyTabDiscardPolicyIfNeeded() async {
        guard let tabManager else { return }
        // Never evict/discard while the UI is transitioning binding/unbinding.
        // During these windows, attachment can be mid-flight; evicting can nil out
        // handles and cause stuck "attaching" + white-screen.
        switch tabManager.activeBindingState {
        case .bound:
            break
        case .binding, .unbinding, .unbound:
            return
        }
        let protected = protectedTabIDsForActivePanes()
        let now = Date()
        let activeIDs: Set<UUID> = {
            var ids = protected
            if let activeTabID = tabManager.activeTabID { ids.insert(activeTabID) }
            return ids
        }()
        let visiblePanesCount: Int = tabManager.visiblePaneCount
        let activeTabCount: Int = activeIDs.count
        let tabStatesByID: [UUID: TabState] = Dictionary(uniqueKeysWithValues: tabManager.tabs.map { ($0.id, $0) })
        let descriptors: [SafariLikeCoreKit.TabResourcePolicy.TabDescriptor] = tabManager.currentTabRegistry.aliveTabIDs.compactMap { tabID in
            guard let store = tabManager.currentTabRegistry.existingStore(for: tabID) else { return nil }
            return SafariLikeCoreKit.TabResourcePolicy.TabDescriptor(
                id: tabID,
                isProtected: protected.contains(tabID),
                isActive: activeIDs.contains(tabID),
                isInSession: tabManager.sessionStore.tabs.contains(where: { $0.id == tabID }),
                // Treat warm-cached webviews as live even when detached from UI.
                hasLiveWebView: store.webViewHandle?.isAlive == true,
                lastActiveAt: tabStatesByID[tabID]?.lastActiveAt
            )
        }
        let decision = tabManager.tabResourcePolicy.decide(
            .init(
                memoryPressureLevel: .none,
                visiblePanesCount: visiblePanesCount,
                activeTabCount: activeTabCount,
                tabs: descriptors,
                now: now,
                discardInactiveAfter: discardConfig.tabInactiveLongThreshold
            )
        )
        for tabID in decision.evict {
            guard let store = tabManager.currentTabRegistry.existingStore(for: tabID) else { continue }
            guard store.webViewHandle?.isAlive == true else { continue }
            await tabManager.pluginHost?.tabWillFreeze(tabID: tabID)
            await tabManager.pluginHost?.tabWillEvict(tabID: tabID)
            // Eviction should drop the WKWebView; not just detach the UI handle.
            tabManager.requestDeactivateWebView(tabID: tabID, mode: .cold, reason: "discard.evict")
            RuntimeMetrics.shared.increment(.webViewDeactivated)
        }
    }
    deinit {
        task?.cancel()
    }
}

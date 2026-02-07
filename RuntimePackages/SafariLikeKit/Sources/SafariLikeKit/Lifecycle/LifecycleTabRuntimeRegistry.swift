import Foundation
import SafariLikeCoreKit
/// Owns active tabs, tab existence, and tabID lifecycle.
@MainActor
final class TabRuntimeRegistry {
    private var activeTabID: UUID?
    private var knownTabIDs: Set<UUID> = []
    func noteTabExists(_ tabID: UUID) {
        knownTabIDs.insert(tabID)
    }
    func setActiveTab(_ tabID: UUID?) {
        activeTabID = tabID
        if let tabID { knownTabIDs.insert(tabID) }
    }
    func currentActiveTabID() -> UUID? {
        activeTabID
    }
    func contains(_ tabID: UUID) -> Bool {
        knownTabIDs.contains(tabID)
    }
    func removeTab(_ tabID: UUID) {
        knownTabIDs.remove(tabID)
        if activeTabID == tabID { activeTabID = nil }
    }
    func requiresWebView(for tabState: BrowserTab.State?) -> Bool {
        guard let tabState else { return false }
        return WebViewRequirementPolicy.decide(tabState: tabState).requiresWebView
    }
}

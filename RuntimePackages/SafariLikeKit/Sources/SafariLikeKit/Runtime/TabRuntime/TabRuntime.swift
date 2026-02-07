import Foundation
import SafariLikeCoreKit
import WebKit
/// Owns the runtime lifecycle for a single tab.
///
/// This is intentionally a thin adapter over `SafariLikeCoreKit.TabRegistry` + `TabWebStore`
/// so we preserve existing behavior (activation, state observation, and eviction policy).
@MainActor
final class TabRuntime {
    let tabID: UUID
    let paneID: String
    private let registry: SafariLikeCoreKit.TabRegistry
    private let role: SafariLikeCoreKit.TabWebStore.Role
    init(
        tabID: UUID,
        paneID: String,
        registry: SafariLikeCoreKit.TabRegistry,
        role: SafariLikeCoreKit.TabWebStore.Role = .primary
    ) {
        self.tabID = tabID
        self.paneID = paneID
        self.registry = registry
        self.role = role
    }
    func existingStore() -> SafariLikeCoreKit.TabWebStore? {
        registry.existingStore(for: tabID)
    }
    func existingWebView() -> WKWebView? {
        existingStore()?.webViewHandle?.webView
    }
    var isWebViewActive: Bool {
        existingStore()?.webViewHandle?.isAlive == true
    }
    func activate(protectedTabIDs: Set<UUID> = []) async -> SafariLikeCoreKit.TabWebStore {
        await registry.activatedStore(for: tabID, paneID: paneID, role: role, protectedTabIDs: protectedTabIDs)
    }
    func ensureStore() async -> SafariLikeCoreKit.TabWebStore {
        await registry.store(for: tabID, paneID: paneID, role: role)
    }
    func removeFromRegistry() async {
        await registry.remove(tabID: tabID)
    }
    func discardWebViewIfNeeded() {
        registry.deactivateWebView(tabID: tabID)
    }
}

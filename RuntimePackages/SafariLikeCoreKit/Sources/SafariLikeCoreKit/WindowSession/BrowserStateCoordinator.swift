import Foundation
import BrowserCore

/// Sits between window/session coordination and the concrete tab runtime (`TabRegistry`/`TabWebStore`).
///
/// Goal: keep higher layers (e.g. `WindowSessionCoordinator`) from knowing about concrete store types.
@MainActor
public protocol BrowserStateCoordinating {
    func existingWebStore(for tabID: UUID) -> (any WebStoreProviding)?

    func activatedWebStore(
        for tabID: UUID,
        role: TabWebStore.Role,
        protectedTabIDs: Set<UUID>
    ) async -> any WebStoreProviding

    func setActivationSuppressed(_ suppressed: Bool)
    func deactivateWebView(tabID: UUID, mode: TabRegistry.WebViewDetachMode)
    func remove(tabID: UUID) async
}

@MainActor
public final class BrowserStateCoordinator: BrowserStateCoordinating {
    private let tabRegistry: TabRegistry

    public init(tabRegistry: TabRegistry) {
        self.tabRegistry = tabRegistry
    }

    public func existingWebStore(for tabID: UUID) -> (any WebStoreProviding)? {
        tabRegistry.existingStore(for: tabID)
    }

    public func activatedWebStore(
        for tabID: UUID,
        role: TabWebStore.Role,
        protectedTabIDs: Set<UUID>
    ) async -> any WebStoreProviding {
        await tabRegistry.activatedStore(for: tabID, role: role, protectedTabIDs: protectedTabIDs)
    }

    public func setActivationSuppressed(_ suppressed: Bool) {
        tabRegistry.setActivationSuppressed(suppressed)
    }

    public func deactivateWebView(tabID: UUID, mode: TabRegistry.WebViewDetachMode) {
        tabRegistry.deactivateWebView(tabID: tabID, mode: mode)
    }

    public func remove(tabID: UUID) async {
        await tabRegistry.remove(tabID: tabID)
    }
}

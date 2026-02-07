import Foundation
import SafariLikeCoreKit
import os
struct TabRuntimeKey: Hashable {
    let tabID: UUID
    let role: SafariLikeCoreKit.TabWebStore.Role
}
@MainActor
final class TabRuntimeFactory {
    weak var tabManager: TabManager?
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
    func runtime(for tabID: UUID, role: SafariLikeCoreKit.TabWebStore.Role = .primary) -> TabRuntime? {
        guard let tabManager else {
            RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
            Logger.runtime.error("TabRuntimeFactory used without TabManager")
            return nil
        }
        let key = TabRuntimeKey(tabID: tabID, role: role)
        let paneID = tabManager.paneID(for: tabID)
        if tabManager.isPrivateMode {
            if let existing = tabManager.privateRuntimes[key] { return existing }
            let created = TabRuntime(tabID: tabID, paneID: paneID, registry: tabManager.privateTabRegistry, role: role)
            tabManager.privateRuntimes[key] = created
            return created
        } else {
            if let existing = tabManager.normalRuntimes[key] { return existing }
            let created = TabRuntime(tabID: tabID, paneID: paneID, registry: tabManager.normalTabRegistry, role: role)
            tabManager.normalRuntimes[key] = created
            return created
        }
    }
    func destroyRuntime(for tabID: UUID) {
        guard let tabManager else {
            RuntimeMetrics.shared.increment(.runtimeInvariantViolation)
            Logger.runtime.error("TabRuntimeFactory used without TabManager")
            return
        }
        if tabManager.isPrivateMode {
            tabManager.privateRuntimes = tabManager.privateRuntimes.filter { $0.key.tabID != tabID }
        } else {
            tabManager.normalRuntimes = tabManager.normalRuntimes.filter { $0.key.tabID != tabID }
        }
    }
}

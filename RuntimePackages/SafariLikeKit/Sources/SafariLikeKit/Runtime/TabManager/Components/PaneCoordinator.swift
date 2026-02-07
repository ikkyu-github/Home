import Foundation
import SafariLikeCoreKit
@MainActor
final class PaneCoordinator {
    weak var tabManager: TabManager?
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
    var protectedTabIDs: Set<UUID> {
        guard let tabManager else { return [] }
        var protected = Set(tabManager.currentVisiblePaneTabIDs())
        switch tabManager.activeBindingState {
        case .bound(let id), .binding(let id):
            protected.insert(id)
        case .unbound, .unbinding:
            break
        }
        return protected
    }
    func applyRestoredSplitTabIDs(_ ids: [UUID]) {
        tabManager?.applyRestoredSplitTabIDs(ids)
    }
}

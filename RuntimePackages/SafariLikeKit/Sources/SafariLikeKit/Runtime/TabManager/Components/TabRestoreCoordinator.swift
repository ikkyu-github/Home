import Foundation
import SafariLikeCoreKit
@MainActor
final class TabRestoreCoordinator {
    weak var tabManager: TabManager?
    init(tabManager: TabManager) {
        self.tabManager = tabManager
    }
}

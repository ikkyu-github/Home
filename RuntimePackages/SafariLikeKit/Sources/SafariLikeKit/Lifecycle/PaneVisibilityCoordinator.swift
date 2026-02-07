import Foundation
import SafariLikeCoreKit
/// Owns which panes/tabs are visible and which tab is currently active.
@MainActor
final class PaneVisibilityCoordinator {
    private var visibleTabIDs: [UUID] = []
    private var activeTabID: UUID?
    func setVisibleTabs(visibleTabIDs: [UUID], activeTabID: UUID?) {
        self.visibleTabIDs = visibleTabIDs
        self.activeTabID = activeTabID
    }
    func currentVisibleTabIDs() -> [UUID] {
        visibleTabIDs
    }
    func isVisible(_ tabID: UUID) -> Bool {
        visibleTabIDs.contains(tabID)
    }
}

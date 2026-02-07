import Foundation
import CoreGraphics
import SafariLikeCoreKit
@MainActor
extension TabManager {
    func updateVisiblePaneMetrics(containerSize: CGSize, safeAreaInsets: CGSize) {
        let panes: [PaneID] = isSplitPanePresentationActive ? [.primary, .secondary] : [.primary]
        for pane in panes {
            guard let context = currentPaneContexts[pane] else { continue }
            context.metrics.lastContainerSize = containerSize
            context.metrics.lastSafeAreaInsets = safeAreaInsets
        }
    }
}

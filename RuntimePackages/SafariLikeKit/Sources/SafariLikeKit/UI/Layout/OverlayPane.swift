import SwiftUI
import SafariLikeCoreKit
internal struct OverlayPane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @ObservedObject var chrome: BrowserChromeState
    let tabOverviewProgress: CGFloat
    let tabOverviewPresentationProgress: CGFloat
    let isDraggingTabOverview: Bool
    let snapshot: BrowserLayoutSnapshot
    let configuration: SafariLikeConfiguration
    var body: some View {
        Group {
            if vm.isTabOverviewVisible || tabOverviewPresentationProgress > 0.001 {
                TabOverviewOverlay(
                    isVisible: $vm.isTabOverviewVisible,
                    progress: tabOverviewProgress,
                    isDragging: isDraggingTabOverview,
                    tabs: vm.tabManager.tabs,
                    tabGroups: vm.sessionStore.tabGroups,
                    selectedTabID: vm.sessionStore.selectedTabID,
                    selectedTabGroupID: vm.sessionStore.selectedTabGroupID,
                    onSelect: { id in vm.selectTab(id) },
                    onClose: { id in vm.closeTab(id) },
                    onNewTab: { vm.newTab() }
                )
            }
        }
    }
}

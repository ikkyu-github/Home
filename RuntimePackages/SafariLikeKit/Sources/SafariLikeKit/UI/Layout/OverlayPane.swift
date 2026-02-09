import SwiftUI
import SafariLikeCoreKit
internal struct OverlayPane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @ObservedObject var chrome: BrowserChromeState
    let snapshot: BrowserLayoutSnapshot
    let configuration: SafariLikeConfiguration
    var body: some View {
        TabOverviewOverlay(
            isVisible: $vm.isTabOverviewVisible,
            progress: snapshot.tabOverviewProgressClamped,
            isDragging: snapshot.isDraggingTabOverview,
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

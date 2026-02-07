import SwiftUI
import SafariLikeCoreKit
internal struct CompanionPane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let isLandscapeSplit: Bool
    let configuration: SafariLikeConfiguration
    let insets: EdgeInsets
    let handleSidebarSelection: (SidebarView.Item, Bool) -> Void
    private var sidebarOverlay: some View {
        SidebarOverlay(
            isVisible: Binding(
                get: { vm.isSidebarVisible },
                set: { isVisible in
                    vm.setSidebarVisible(isVisible)
                }
            ),
            width: configuration.sidebarWidth,
            viewModel: vm
            ,
            panelTopPadding: isLandscapeSplit ? insets.top : nil,
            panelLeadingPadding: isLandscapeSplit ? insets.leading : nil
        ) { item in
            handleSidebarSelection(item, false)
        }
    }
    var body: some View {
        Group {
            if vm.isSidebarVisible {
                sidebarOverlay
            }
        }
    }
}

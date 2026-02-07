import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
import SafariLikeContracts
internal struct PrimaryPane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @ObservedObject var chrome: BrowserChromeState
    let configuration: SafariLikeConfiguration
    let insets: EdgeInsets
    let isLandscapeSplit: Bool
    let isSplitUIPresented: Bool
    let browserRootWidth: CGFloat
    let tabOverviewProgress: CGFloat
    let handleSidebarSelection: (SidebarView.Item, Bool) -> Void
    @Environment(\.isLayoutStabilizing) private var isLayoutStabilizing
    @Environment(\.uxPolicy) private var uxPolicy
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // ---- Tab content ----
                Group {
                    BrowserView(
                        vm: vm,
                        safeAreaInsets: insets,
                        configuration: configuration,
                        onSidebarSelect: { item in
                            handleSidebarSelection(item, isLandscapeSplit)
                        }
                    )
                    .transition(.opacity)
                }
                .animation(isLayoutStabilizing ? nil : .easeInOut(duration: 0.18), value: vm.activeTabID)
                .zIndex(0)
                if chrome.chromeSnapshot.isOmniboxOverlayVisible {
					// OmniboxOverlayView is presented within the safe area; do not double-count insets.
                    let reservedTop = max(
                        0,
                        SafariHeaderView.height(
                            for: chrome.chromeStyle,
                            isEditing: vm.bar.addressBarViewState.isTextInputFocused
                        )
                    )
					let bottomBarHeight: CGFloat = {
						guard chrome.chromeStyle == .phonePortraitSafari else { return 0 }
                        return vm.bar.addressBarViewState.isTextInputFocused
							? PhonePortraitBottomBar.LayoutMetrics.expandedHeight
							: PhonePortraitBottomBar.LayoutMetrics.compactHeight
					}()
					let reservedBottom = max(0, bottomBarHeight)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: reservedTop).allowsHitTesting(false)
                        OmniboxOverlayView(bar: vm.bar).frame(maxWidth: .infinity, maxHeight: .infinity)
                        Color.clear.frame(height: reservedBottom).allowsHitTesting(false)
                    }
                    .zIndex(uxPolicy.layout.zOrder.omniboxOverlay)
                }
            }
            .safariTabOverviewTransform(progress: tabOverviewProgress, isLandscapeSplit: isLandscapeSplit)
        }
    }
}

import SwiftUI

/// Single overlay orchestrator for the browser surface.
///
/// Commit 1 contract:
/// - Does NOT change internal overlay behaviors.
/// - Only centralizes layering (z-order) and provides conservative pass-through hit-testing.
internal struct BrowserOverlayStack: View {
    let vm: SplitBrowserViewModel
    let chrome: BrowserChromeState
    let tabOverviewProgress: CGFloat
    let tabOverviewPresentationProgress: CGFloat
    let isDraggingTabOverview: Bool
    let snapshot: BrowserLayoutSnapshot
    let configuration: SafariLikeConfiguration

    @EnvironmentObject private var relatedChrome: RelatedChromeState

    private var isAnyOverlayVisible: Bool {
        relatedChrome.isVisible
            || vm.isTabOverviewVisible
            || tabOverviewPresentationProgress > 0.001
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RelatedContainerView(vm: vm, snapshot: snapshot)

            OverlayPane(
                vm: vm,
                chrome: chrome,
                tabOverviewProgress: tabOverviewProgress,
                tabOverviewPresentationProgress: tabOverviewPresentationProgress,
                isDraggingTabOverview: isDraggingTabOverview,
                snapshot: snapshot,
                configuration: configuration
            )
        }
        // Pass-through when no overlays are visible.
        .allowsHitTesting(isAnyOverlayVisible)
    }
}

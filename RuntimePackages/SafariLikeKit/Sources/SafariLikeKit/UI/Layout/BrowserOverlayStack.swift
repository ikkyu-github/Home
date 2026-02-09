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

    @Environment(\.browserLayoutMode) private var layoutMode
    @EnvironmentObject private var relatedChrome: RelatedChromeState

    private var isTabOverviewActive: Bool {
        vm.isTabOverviewVisible || tabOverviewPresentationProgress > 0.001
    }

    // Keep this consistent with `TabOverviewOverlay`'s own hit-testing gate.
    private var isTabOverviewHitTestingEnabled: Bool {
        tabOverviewPresentationProgress > 0.1
            || vm.isTabOverviewVisible
            || isDraggingTabOverview
    }

    private var isRelatedActive: Bool {
        // Policy: do not allow Related to compete with Tab Overview.
        // If both states are true transiently, Tab Overview wins.
        layoutMode == .phonePortrait
            && relatedChrome.isVisible
            && isTabOverviewActive == false
    }

    private var isOverlayHitTestingEnabled: Bool {
        isRelatedActive || isTabOverviewHitTestingEnabled
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            relatedOverlay
                .zIndex(0)

            tabOverviewOverlay
                .zIndex(10)
        }
        // Pass-through unless an overlay is *visibly* interactive.
        .allowsHitTesting(isOverlayHitTestingEnabled)
    }

    @ViewBuilder
    private var relatedOverlay: some View {
        if isRelatedActive {
            GeometryReader { geo in
                let insets = snapshot.effectiveSafeAreaInsets
                let chromeHeight = SafariHeaderView.height(for: .phonePortraitSafari) + insets.bottom
                // Keep the bottom chrome area tappable; the scrim is still full-screen visually.
                let scrimExclusionHeight = chromeHeight
                // Reserve real space for bottom chrome instead of manual padding.
                let reservedBottom: CGFloat = chromeHeight + 10

                let availableDrawerHeight = max(0, geo.size.height - reservedBottom)
                let mediumHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.55))
                let largeHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.85))

                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.20)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .contentShape(ScrimHitShape(excludingBottom: scrimExclusionHeight))
                        .onTapGesture {
                            relatedChrome.setVisible(false, animation: .easeOut(duration: 0.2))
                        }

                    RelatedContainerView(
                        vm: vm,
                        mediumHeight: mediumHeight,
                        largeHeight: largeHeight
                    )
                    .transition(.move(edge: .bottom))
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // Keep chrome area deterministic; reserve space without creating a tap blocker.
                    Color.clear
                        .frame(height: reservedBottom)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.25), value: relatedChrome.isVisible)
        }
    }

    @ViewBuilder
    private var tabOverviewOverlay: some View {
        if isTabOverviewActive {
            OverlayPane(
                vm: vm,
                chrome: chrome,
                tabOverviewProgress: tabOverviewProgress,
                tabOverviewPresentationProgress: tabOverviewPresentationProgress,
                isDraggingTabOverview: isDraggingTabOverview,
                snapshot: snapshot,
                configuration: configuration
            )
            // Avoid "transparent but still receiving touches".
            .allowsHitTesting(isTabOverviewHitTestingEnabled)
        }
    }
}

private struct ScrimHitShape: Shape {
    let excludingBottom: CGFloat

    func path(in rect: CGRect) -> Path {
        let height = max(0, rect.height - excludingBottom)
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: height))
        return path
    }
}

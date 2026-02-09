import SwiftUI

/// Single overlay orchestrator for the browser surface.
///
/// Commit 1 contract:
/// - Does NOT change internal overlay behaviors.
/// - Only centralizes layering (z-order) and provides conservative pass-through hit-testing.
internal struct BrowserOverlayStack: View {
    let vm: SplitBrowserViewModel
    let chrome: BrowserChromeState
    let snapshot: BrowserLayoutSnapshot
    let configuration: SafariLikeConfiguration

    @Environment(\.browserLayoutMode) private var layoutMode
    @EnvironmentObject private var relatedChrome: RelatedChromeState

    private func isTabOverviewActive(_ snapshot: BrowserLayoutSnapshot) -> Bool {
        snapshot.isTabOverviewVisible || snapshot.tabOverviewPresentationProgress > 0.001
    }

    // Keep this consistent with `TabOverviewOverlay`'s own hit-testing gate.
    private func isTabOverviewHitTestingEnabled(_ snapshot: BrowserLayoutSnapshot) -> Bool {
        snapshot.tabOverviewPresentationProgress > 0.1
            || snapshot.isTabOverviewVisible
            || snapshot.isDraggingTabOverview
    }

    private func isRelatedActive(layoutMode: BrowserLayoutMode, relatedChrome: RelatedChromeState, snapshot: BrowserLayoutSnapshot) -> Bool {
        // Policy: do not allow Related to compete with Tab Overview.
        // If both states are true transiently, Tab Overview wins.
        layoutMode == .phonePortrait
            && relatedChrome.isVisible
            && isTabOverviewActive(snapshot) == false
    }

    private func overlayHitTestingEnabled(layoutMode: BrowserLayoutMode, relatedChrome: RelatedChromeState, snapshot: BrowserLayoutSnapshot) -> Bool {
        isRelatedActive(layoutMode: layoutMode, relatedChrome: relatedChrome, snapshot: snapshot)
            || isTabOverviewHitTestingEnabled(snapshot)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            relatedOverlay
                .zIndex(0)

            tabOverviewOverlay
                .zIndex(10)
        }
        // Pass-through unless an overlay is *visibly* interactive.
        .allowsHitTesting(overlayHitTestingEnabled(layoutMode: layoutMode, relatedChrome: relatedChrome, snapshot: snapshot))
    }

    @ViewBuilder
    private var relatedOverlay: some View {
        if isRelatedActive(layoutMode: layoutMode, relatedChrome: relatedChrome, snapshot: snapshot) {
            GeometryReader { geo in
                // Keep the bottom chrome area tappable; the scrim is still full-screen visually.
                // Use the contract rect (not a bottom strip) so keyboard lift doesn't accidentally re-enable scrim over chrome.
                let chromeBottomRect = snapshot.chromeBottomRect
                let viewportRect = snapshot.contentViewportRect
                // Place the drawer within the content viewport (single truth).
                let bottomOffset = max(0, geo.size.height - viewportRect.maxY)
                let availableDrawerHeight = max(0, viewportRect.height)
                let mediumHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.55))
                let largeHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.85))

                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.20)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .contentShape(ScrimHitShapeExcludingRect(excluded: chromeBottomRect))
                        .onTapGesture {
                            relatedChrome.setVisible(false, animation: .easeOut(duration: 0.2))
                        }

                    RelatedContainerView(
                        vm: vm,
                        mediumHeight: mediumHeight,
                        largeHeight: largeHeight
                    )
                    .transition(.move(edge: .bottom))
                    .padding(.bottom, bottomOffset)
                }
            }
            .animation(.easeOut(duration: 0.25), value: relatedChrome.isVisible)
        }
    }

    @ViewBuilder
    private var tabOverviewOverlay: some View {
        if isTabOverviewActive(snapshot) {
            OverlayPane(
                vm: vm,
                chrome: chrome,
                snapshot: snapshot,
                configuration: configuration
            )
            // Avoid "transparent but still receiving touches".
            .allowsHitTesting(isTabOverviewHitTestingEnabled(snapshot))
        }
    }
}

private struct ScrimHitShapeExcludingRect: Shape {
    let excluded: CGRect

    func path(in rect: CGRect) -> Path {
        // We only support excluding a full-width horizontal band.
        // That matches our chrome contract (bottom bar spans full width).
        let excludedMinY = max(rect.minY, min(rect.maxY, excluded.minY))
        let excludedMaxY = max(rect.minY, min(rect.maxY, excluded.maxY))

        var path = Path()
        // Above excluded
        if excludedMinY > rect.minY {
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: excludedMinY - rect.minY))
        }
        // Below excluded
        if excludedMaxY < rect.maxY {
            path.addRect(CGRect(x: rect.minX, y: excludedMaxY, width: rect.width, height: rect.maxY - excludedMaxY))
        }
        return path
    }
}

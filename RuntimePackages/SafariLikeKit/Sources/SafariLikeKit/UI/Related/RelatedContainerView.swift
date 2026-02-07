import SwiftUI
#if canImport(UIKit)
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
/// Centralized Related presenter driven only by `BrowserLayoutMode`.
internal struct RelatedContainerView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @Environment(\.browserLayoutMode) private var layoutMode
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    private enum DrawerDetent: CaseIterable {
        case medium
        case large
    }
    @State private var currentDetent: DrawerDetent = .medium
    @State private var drawerHeightOverride: CGFloat? = nil
    @State private var isDraggingDrawer: Bool = false
    @State private var dragStartHeight: CGFloat = 0
    var body: some View {
        switch layoutMode {
        case .phonePortrait:
            phonePortraitOverlay
        case .tabletLandscape:
            EmptyView()
        }
    }
    private var phonePortraitOverlay: some View {
        GeometryReader { geo in
            let insetsUI = (sceneMetrics.stableInsets != .zero) ? sceneMetrics.stableInsets : UIEdgeInsets.zero
            let chromeHeight = SafariHeaderView.height(for: .phonePortraitSafari) + insetsUI.bottom
            // Keep the bottom chrome area tappable; the scrim is still full-screen visually.
            let scrimExclusionHeight = chromeHeight
            // Reserve real space for bottom chrome instead of manual padding.
            let reservedBottom: CGFloat = chromeHeight + 10
            let availableDrawerHeight = max(0, geo.size.height - reservedBottom)
            let mediumHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.55))
            let largeHeight = min(availableDrawerHeight, max(260, availableDrawerHeight * 0.85))
            let detentHeight: (DrawerDetent) -> CGFloat = { detent in
                switch detent {
                case .medium: return mediumHeight
                case .large: return largeHeight
                }
            }
            let clampedDrawerHeight: (CGFloat) -> CGFloat = { height in
                min(max(height, mediumHeight), largeHeight)
            }
            let currentHeight = clampedDrawerHeight(drawerHeightOverride ?? detentHeight(currentDetent))
            let grabberHeight: CGFloat = 24
            ZStack(alignment: .bottom) {
                if relatedChrome.isVisible {
                    Color.black.opacity(0.20)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .contentShape(ScrimHitShape(excludingBottom: scrimExclusionHeight))
                        .onTapGesture {
                            relatedChrome.setVisible(false, animation: .easeOut(duration: 0.2))
                        }
                    VStack(spacing: 0) {
                        DrawerGrabber()
                            .frame(height: grabberHeight)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 3, coordinateSpace: .local)
                                    .onChanged { value in
                                        if isDraggingDrawer == false {
                                            isDraggingDrawer = true
                                            dragStartHeight = currentHeight
                                        }
                                        // Drag up => increase height; drag down => decrease height.
                                        let proposed = dragStartHeight + (-value.translation.height)
                                        let next = clampedDrawerHeight(proposed)
                                        withTransaction(Transaction(animation: nil)) {
                                            drawerHeightOverride = next
                                        }
                                    }
                                    .onEnded { _ in
                                        isDraggingDrawer = false
                                        let candidateHeights: [CGFloat] = [mediumHeight, largeHeight]
                                        let nearest = candidateHeights.min(by: { abs($0 - currentHeight) < abs($1 - currentHeight) }) ?? mediumHeight
                                        let snappedDetent: DrawerDetent = (abs(nearest - largeHeight) < abs(nearest - mediumHeight)) ? .large : .medium
                                        withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86, blendDuration: 0.12)) {
                                            currentDetent = snappedDetent
                                            drawerHeightOverride = nil
                                        }
                                    }
                            )
                        // Do not replace CompanionListView; it must remain the scrollable content.
                        CompanionListView(
                            items: vm.relatedItems,
                            currentURLString: vm.activeURLString,
                            onSelect: { item in vm.openCompanionItem(item) },
                            onClose: { relatedChrome.setVisible(false, animation: .easeOut(duration: 0.2)) },
                            onOpenInNewTab: { item in vm.openCompanionItemInNewTab(item) }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: currentHeight)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                            .allowsHitTesting(false)
                    )
                    .padding(.horizontal, 10)
                    .transition(.move(edge: .bottom))
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Keep chrome area deterministic; reserve space without creating a tap blocker.
                Color.clear
                    .frame(height: reservedBottom)
                    .allowsHitTesting(false)
            }
            .animation(.easeOut(duration: 0.25), value: relatedChrome.isVisible)
            // Critical: when not visible, this overlay must be a pure pass-through.
            .allowsHitTesting(relatedChrome.isVisible)
        }
    }
}
private struct DrawerGrabber: View {
    var body: some View {
        ZStack {
            Color.clear
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.25))
                .frame(width: 44, height: 5)
        }
        .frame(maxWidth: .infinity)
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
#else
/// Non-iOS stub to keep indexing happy when UIKit isn't available.
internal struct RelatedContainerView: View {
    var body: some View { EmptyView() }
}
#endif

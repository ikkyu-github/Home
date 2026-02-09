import SwiftUI
#if canImport(UIKit)
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
/// Related drawer content (phone-portrait overlay).
///
/// Overlay policies (scrim, reserved chrome space, hit-testing gating) are owned by `BrowserOverlayStack`.
internal struct RelatedContainerView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @EnvironmentObject private var relatedChrome: RelatedChromeState

    let mediumHeight: CGFloat
    let largeHeight: CGFloat

    private enum DrawerDetent: CaseIterable {
        case medium
        case large
    }
    @State private var currentDetent: DrawerDetent = .medium
    @State private var drawerHeightOverride: CGFloat? = nil
    @State private var isDraggingDrawer: Bool = false
    @State private var dragStartHeight: CGFloat = 0

    var body: some View {
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
#else
/// Non-iOS stub to keep indexing happy when UIKit isn't available.
import SafariLikeCoreKit
internal struct RelatedContainerView: View {
    let vm: SplitBrowserViewModel
    let mediumHeight: CGFloat
    let largeHeight: CGFloat

    var body: some View { EmptyView() }
}
#endif

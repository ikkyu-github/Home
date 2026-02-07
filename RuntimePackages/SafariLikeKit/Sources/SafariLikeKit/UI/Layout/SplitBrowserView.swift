import SwiftUI
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
/// Safari-style split view with two web panes sharing tabs
struct SplitBrowserView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let configuration: SafariLikeConfiguration
    let browserRootWidth: CGFloat
    private static func parsePlaceholderID(_ raw: String) -> UUID {
        if let uuid = UUID(uuidString: raw) { return uuid }
        assertionFailure("Invalid SplitBrowserView placeholder UUID: \(raw)")
        return UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }
    private static let leftPlaceholderID: UUID = parsePlaceholderID("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")
    private static let rightPlaceholderID: UUID = parsePlaceholderID("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @Environment(\.isLayoutStabilizing) private var isLayoutStabilizing
    @Environment(\.uxPolicy) private var uxPolicy
    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    private var minPaneWidth: CGFloat { uxPolicy.splitBrowser.minPaneWidth }
    private let dividerWidth: CGFloat = 10
    private func uxRestoreState(for tabID: UUID?) -> UXRestoreController.State {
        guard let tabID else { return .idle }
        return vm.uxRestoreStateIfAlive(tabID: tabID) ?? .idle
    }
    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let effectiveMinPaneWidth = min(minPaneWidth, max(0, (totalWidth - dividerWidth) / 2))
            let ratio = resolvedRatio(totalWidth: totalWidth, minPaneWidth: effectiveMinPaneWidth)
            let leftPaneWidth = calculateLeftPaneWidth(totalWidth: totalWidth, ratio: ratio, minPaneWidth: effectiveMinPaneWidth)
            let rightPaneWidth = max(0, totalWidth - leftPaneWidth - dividerWidth)
            ZStack(alignment: .topTrailing) {
                splitContent(
                    totalWidth: totalWidth,
                    leftPaneWidth: leftPaneWidth,
                    rightPaneWidth: rightPaneWidth,
                    minPaneWidth: effectiveMinPaneWidth
                )
                closeButton
            }
        }
        .onAppear {
            vm.ensureSplitViewInvariantsIfNeeded()
        }
        .onChange(of: vm.rightTabID) { _ in
            vm.ensureSplitViewInvariantsIfNeeded()
        }
    }
    // MARK: - Layers
    @ViewBuilder
    private func splitContent(
        totalWidth: CGFloat,
        leftPaneWidth: CGFloat,
        rightPaneWidth: CGFloat,
        minPaneWidth: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            // Do not reserve a split pane if the tab doesn't exist yet.
            // The ViewModel invariant fixer will create/repair tab IDs immediately.
            if let leftID = vm.leftTabID, let rightID = vm.rightTabID, leftID != rightID {
                pane(
                    side: .left,
                    width: leftPaneWidth,
                    tabID: leftID,
                    placeholderID: Self.leftPlaceholderID,
                    indicatorAlignment: .topLeading
                )
                divider(totalWidth: totalWidth, minPaneWidth: minPaneWidth)
                pane(
                    side: .right,
                    width: rightPaneWidth,
                    tabID: rightID,
                    placeholderID: Self.rightPlaceholderID,
                    indicatorAlignment: .topTrailing
                )
            } else {
                pane(
                    side: .left,
                    width: totalWidth,
                    tabID: vm.leftTabID,
                    placeholderID: Self.leftPlaceholderID,
                    indicatorAlignment: .topLeading
                )
            }
        }
        .animation(isLayoutStabilizing ? nil : .easeInOut(duration: 0.20), value: vm.activePane)
    }
    private enum PaneSide { case left, right }
    @ViewBuilder
    private func pane(
        side: PaneSide,
        width: CGFloat,
        tabID: UUID?,
        placeholderID: UUID,
        indicatorAlignment: Alignment
    ) -> some View {
        let isFocused = (vm.activePane == (side == .left ? .left : .right))
        let restoreState = uxRestoreState(for: tabID)
        let snapshotData = tabID.flatMap { vm.tabManager.snapshotDataForTabIfAvailable($0) }
        ZStack {
            if let tabID, let handle = vm.webViewHandleForRendering(tabID: tabID) {
                WebView(
                        webViewHandle: handle,
                    realityUpdater: vm.runtimeRealityUpdaterIfAlive(for: tabID),
                        headerView: SafariHeaderView(
                            vm: vm,
                            style: .padLandscapeSafari,
                            topBarMode: .passive
                        ),
                        onScroll: { offset, scrollView in
                            chrome.handleWebScroll(contentOffset: offset, scrollView: scrollView)
                            vm.handleWebScroll(contentOffset: offset, scrollView: scrollView)
                        },
                        onSwipeBack: { vm.send(.goBack) },
                        onSwipeForward: { vm.send(.goForward) },
                        canSwipeBack: { vm.sessionStore.canGoBack(tabID: tabID) },
                        canSwipeForward: { vm.sessionStore.canGoForward(tabID: tabID) },
                        onPullToRefresh: { vm.send(.reload) },
                        identity: tabID,
                        onFocus: {
                            switch side {
                            case .left: vm.selectLeftPane()
                            case .right: vm.selectRightPane()
                            }
                        },
                        edgeSwipePolicy: uxPolicy.swipeNavigation
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                PanePlaceholder(state: restoreState, snapshotData: snapshotData)
            }
            RestoreOverlayLayer(state: restoreState, snapshotData: snapshotData)
                .equatable()
        }
        .frame(width: width)
        .clipped()
        .modifier(PaneChromeModifier(isFocused: isFocused, indicatorAlignment: indicatorAlignment))
    }
    private func divider(totalWidth: CGFloat, minPaneWidth: CGFloat) -> some View {
        ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.secondary.opacity(isDragging ? 0.55 : 0.25), lineWidth: 1)
                )
                .padding(.vertical, 10)
                .padding(.horizontal, 2)
            VStack(spacing: 4) {
                Capsule().fill(Color.secondary.opacity(0.55)).frame(width: 3, height: 18)
                Capsule().fill(Color.secondary.opacity(0.35)).frame(width: 3, height: 18)
            }
            .padding(.vertical, 14)
        }
        .frame(width: dividerWidth)
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation.width
                }
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { value in
                    isDragging = false
                    commitDrag(totalWidth: totalWidth, translation: value.translation.width, minPaneWidth: minPaneWidth)
                }
        )
        .accessibilityLabel("Resize Split")
        .animation(isLayoutStabilizing ? nil : .easeInOut(duration: 0.18), value: isDragging)
    }
    private var closeButton: some View {
        Button {
            vm.closeSpinView()
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.secondary)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                )
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .padding(12)
        .zIndex(100)
        .accessibilityLabel("Close Split View")
    }
    private func resolvedRatio(totalWidth: CGFloat, minPaneWidth: CGFloat) -> CGFloat {
        let (minRatio, maxRatio) = ratioBounds(totalWidth: totalWidth, minPaneWidth: minPaneWidth)
        let baseRatio = clamp(vm.splitViewRatio, minRatio, maxRatio)
        let proposedRatio = baseRatio + (dragTranslation / max(1, totalWidth))
        // Rubber-band when dragging beyond bounds.
        if proposedRatio < minRatio {
            let overflow = (proposedRatio - minRatio) * totalWidth
            let adjustedOverflow = rubberBand(distance: overflow, dimension: totalWidth)
            return minRatio + (adjustedOverflow / totalWidth)
        }
        if proposedRatio > maxRatio {
            let overflow = (proposedRatio - maxRatio) * totalWidth
            let adjustedOverflow = rubberBand(distance: overflow, dimension: totalWidth)
            return maxRatio + (adjustedOverflow / totalWidth)
        }
        return proposedRatio
    }
    private func commitDrag(totalWidth: CGFloat, translation: CGFloat, minPaneWidth: CGFloat) {
        let (minRatio, maxRatio) = ratioBounds(totalWidth: totalWidth, minPaneWidth: minPaneWidth)
        let baseRatio = clamp(vm.splitViewRatio, minRatio, maxRatio)
        let proposedRatio = baseRatio + (translation / max(1, totalWidth))
        let committed = clamp(proposedRatio, minRatio, maxRatio)
        if isLayoutStabilizing {
            vm.splitViewRatio = committed
        } else {
            withAnimation(.easeInOut(duration: 0.18)) {
                vm.splitViewRatio = committed
            }
        }
    }
    private func calculateLeftPaneWidth(totalWidth: CGFloat, ratio: CGFloat, minPaneWidth: CGFloat) -> CGFloat {
        let baseWidth = totalWidth * ratio
        // Ensure minimum width for both panes.
        let available = max(0, totalWidth - dividerWidth)
        let maxLeftWidth = max(0, available - minPaneWidth)
        let minLeftWidth = minPaneWidth
        return max(minLeftWidth, min(maxLeftWidth, baseWidth))
    }
    private func ratioBounds(totalWidth: CGFloat, minPaneWidth: CGFloat) -> (min: CGFloat, max: CGFloat) {
        // Convert min widths into ratio bounds for the current container.
        let minRatio = min(0.49, max(0.01, minPaneWidth / max(1, totalWidth)))
        let maxRatio = max(0.51, min(0.99, (totalWidth - dividerWidth - minPaneWidth) / max(1, totalWidth)))
        return (min: minRatio, max: maxRatio)
    }
    private func clamp(_ value: CGFloat, _ minValue: CGFloat, _ maxValue: CGFloat) -> CGFloat {
        max(minValue, min(maxValue, value))
    }
    private func rubberBand(distance: CGFloat, dimension: CGFloat) -> CGFloat {
        // iOS-style rubber banding.
        // For small overdrag, movement is close to 1:1; it asymptotically slows for large distances.
        let constant: CGFloat = 0.55
        return (dimension * constant * distance) / (dimension + constant * abs(distance))
    }
}
private struct PanePlaceholder: View {
    let state: UXRestoreController.State
    let snapshotData: Data?
    var body: some View {
        switch state {
        case .timedOut:
            SkeletonWebPlaceholder()
        case .idle, .completed, .restoring:
            Color.gray.opacity(0.1)
        @unknown default:
            SkeletonWebPlaceholder()
        }
    }
}
private struct RestoreOverlayLayer: View, Equatable {
    let state: UXRestoreController.State
    let snapshotData: Data?
    static func == (lhs: RestoreOverlayLayer, rhs: RestoreOverlayLayer) -> Bool {
        lhs.state == rhs.state && lhs.snapshotData == rhs.snapshotData
    }
    @ViewBuilder
    var body: some View {
        switch state {
        case .restoring:
            if let snapshotData {
                RestoreOverlay(snapshotData: snapshotData)
                    .transition(.opacity)
            } else {
                EmptyView()
            }
        case .timedOut:
            SkeletonWebPlaceholder()
                .transition(.opacity)
        case .idle, .completed:
            EmptyView()
        @unknown default:
            SkeletonWebPlaceholder()
                .transition(.opacity)
        }
    }
}
private struct PaneChromeModifier: ViewModifier {
    let isFocused: Bool
    let indicatorAlignment: Alignment
    @Environment(\.isLayoutStabilizing) private var isLayoutStabilizing
    func body(content: Content) -> some View {
        content
            .overlay(
                Color.black.opacity(isFocused ? 0 : 0.06)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? Color.accentColor.opacity(0.55) : Color.clear, lineWidth: 1.5)
                    .padding(6)
                    .allowsHitTesting(false)
            )
            .overlay(alignment: indicatorAlignment) {
                Circle()
                    .fill(isFocused ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(isFocused ? 0.10 : 0.0), radius: isFocused ? 10 : 0, x: 0, y: 4)
            .animation(isLayoutStabilizing ? nil : .easeInOut(duration: 0.20), value: isFocused)
    }
}

import SwiftUI

public struct SafariEdgeGestureLayerPane: View {
    @Binding var isSidebarVisible: Bool
    @Binding var isTabOverviewVisible: Bool
    @Binding var tabOverviewProgress: CGFloat
    @Binding var isDraggingTabOverview: Bool
    let topInset: CGFloat

    public init(
        isSidebarVisible: Binding<Bool>,
        isTabOverviewVisible: Binding<Bool>,
        tabOverviewProgress: Binding<CGFloat>,
        isDraggingTabOverview: Binding<Bool>,
        topInset: CGFloat
    ) {
        self._isSidebarVisible = isSidebarVisible
        self._isTabOverviewVisible = isTabOverviewVisible
        self._tabOverviewProgress = tabOverviewProgress
        self._isDraggingTabOverview = isDraggingTabOverview
        self.topInset = topInset
    }

    public var body: some View {
        SafariEdgeGestureLayer(
            isSidebarVisible: $isSidebarVisible,
            isTabOverviewVisible: $isTabOverviewVisible,
            progress: $tabOverviewProgress,
            isDragging: $isDraggingTabOverview,
            topInset: topInset
        )
    }
}

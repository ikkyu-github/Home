import SwiftUI

public struct SafariEdgeGestureLayer: View {
    @Binding var isSidebarVisible: Bool
    @Binding var isTabOverviewVisible: Bool
    @Binding var progress: CGFloat
    @Binding var isDragging: Bool
    let topInset: CGFloat

    public init(
        isSidebarVisible: Binding<Bool>,
        isTabOverviewVisible: Binding<Bool>,
        progress: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        topInset: CGFloat
    ) {
        self._isSidebarVisible = isSidebarVisible
        self._isTabOverviewVisible = isTabOverviewVisible
        self._progress = progress
        self._isDragging = isDragging
        self.topInset = topInset
    }

    public var body: some View {
        // Placeholder: pass-through, no gesture logic yet
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .allowsHitTesting(false)
    }
}

import SwiftUI
import SafariLikeCoreKit
/// Sidebar overlay (scrim + sidebar panel).
internal struct SidebarOverlay: View {
    @Binding var isVisible: Bool
    let width: CGFloat
    let viewModel: SplitBrowserViewModel
    let panelTopPadding: CGFloat?
    let panelLeadingPadding: CGFloat?
    let excludedHitBands: [CGRect]
    let onSelect: (SidebarView.Item) -> Void
    init(
        isVisible: Binding<Bool>,
        width: CGFloat,
        viewModel: SplitBrowserViewModel,
        panelTopPadding: CGFloat? = nil,
        panelLeadingPadding: CGFloat? = nil,
        excludedHitBands: [CGRect] = [],
        onSelect: @escaping (SidebarView.Item) -> Void
    ) {
        self._isVisible = isVisible
        self.width = width
        self.viewModel = viewModel
        self.panelTopPadding = panelTopPadding
        self.panelLeadingPadding = panelLeadingPadding
        self.excludedHitBands = excludedHitBands
        self.onSelect = onSelect
    }
    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .contentShape(ScrimHitShapeExcludingBands(excludedBands: excludedHitBands))
                .allowsHitTesting(isVisible)
                .onTapGesture { self.isVisible = false }
            SidebarPaneView(
                vm: viewModel,
                isOverlay: true,
                onSelect: onSelect
            )
            .frame(width: width)
            .background(.ultraThinMaterial)
            .modifier(PanelPadding(top: panelTopPadding, leading: panelLeadingPadding))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Avoid invisible tap blockers during transition out.
        .allowsHitTesting(isVisible)
        .transition(.move(edge: .leading))
    }
}

private struct ScrimHitShapeExcludingBands: Shape {
    let excludedBands: [CGRect]

    func path(in rect: CGRect) -> Path {
        // Supports excluding full-width horizontal bands (top/bottom chrome).
        let bands = excludedBands
            .filter { $0.height > 0.5 }
            .map { band in
                let minY = max(rect.minY, min(rect.maxY, band.minY))
                let maxY = max(rect.minY, min(rect.maxY, band.maxY))
                return (minY: minY, maxY: maxY)
            }
            .sorted(by: { $0.minY < $1.minY })

        var path = Path()
        var cursorY = rect.minY
        for band in bands {
            if band.minY > cursorY {
                path.addRect(CGRect(x: rect.minX, y: cursorY, width: rect.width, height: band.minY - cursorY))
            }
            cursorY = max(cursorY, band.maxY)
        }
        if cursorY < rect.maxY {
            path.addRect(CGRect(x: rect.minX, y: cursorY, width: rect.width, height: rect.maxY - cursorY))
        }
        return path
    }
}
private struct PanelPadding: ViewModifier {
    let top: CGFloat?
    let leading: CGFloat?
    func body(content: Content) -> some View {
        var result: AnyView = AnyView(content)
        if let top {
            result = AnyView(result.padding(.top, top))
        }
        if let leading {
            result = AnyView(result.padding(.leading, leading))
        }
        return result
    }
}

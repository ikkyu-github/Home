import SwiftUI
import SafariLikeCoreKit
/// Sidebar overlay (scrim + sidebar panel).
internal struct SidebarOverlay: View {
    @Binding var isVisible: Bool
    let width: CGFloat
    let viewModel: SplitBrowserViewModel
    let panelTopPadding: CGFloat?
    let panelLeadingPadding: CGFloat?
    let onSelect: (SidebarView.Item) -> Void
    init(
        isVisible: Binding<Bool>,
        width: CGFloat,
        viewModel: SplitBrowserViewModel,
        panelTopPadding: CGFloat? = nil,
        panelLeadingPadding: CGFloat? = nil,
        onSelect: @escaping (SidebarView.Item) -> Void
    ) {
        self._isVisible = isVisible
        self.width = width
        self.viewModel = viewModel
        self.panelTopPadding = panelTopPadding
        self.panelLeadingPadding = panelLeadingPadding
        self.onSelect = onSelect
    }
    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.opacity(0.25)
                .ignoresSafeArea()
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
        .transition(.move(edge: .leading))
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

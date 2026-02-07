import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
/// Docked side pane presenter for the "Related" UI.
/// This must be inserted as a sibling of the WebView canvas (HStack), not as an overlay.
internal struct RelatedSidePane: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    @State private var frozenRelatedItems: [CompanionItem] = []
    private var allowsLiveRelated: Bool {
        RelatedPolicy.allowsLiveRelated(
            for: .init(
                isInOverview: vm.isTabOverviewVisible,
                hasActiveTab: vm.activeTabID != nil
            )
        )
    }
    private var closeRelated: () -> Void {
        { relatedChrome.setVisible(false, animation: .easeOut(duration: 0.2)) }
    }
    var body: some View {
        Group {
            if relatedChrome.isVisible {
                CompanionListView(
                    items: allowsLiveRelated ? vm.relatedItems : frozenRelatedItems,
                    currentURLString: vm.activeURLString,
                    onSelect: { item in vm.openCompanionItem(item) },
                    onClose: closeRelated,
                    onOpenInNewTab: { item in vm.openCompanionItemInNewTab(item) }
                )
                .background(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.primary.opacity(0.10))
                        .frame(width: 1),
                    alignment: .leading
                )
                .onAppear {
                    if frozenRelatedItems.isEmpty { frozenRelatedItems = vm.relatedItems }
                }
                .onChange(of: allowsLiveRelated) { newValue in
                    if newValue == false { frozenRelatedItems = vm.relatedItems }
                }
            }
        }
    }
}

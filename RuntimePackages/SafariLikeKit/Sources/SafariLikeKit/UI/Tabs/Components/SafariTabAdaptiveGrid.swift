import SwiftUI
import SafariLikeCoreKit
internal struct SafariTabAdaptiveGrid: View {
    let tabs: [TabState]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let columns: Int
    let cardSize: CGSize
    let sectionInsets: EdgeInsets
    let interCardSpacing: CGFloat
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onScrollOffsetChanged: ((CGFloat) -> Void)?
    private var gridItems: [GridItem] {
        Array(repeating: GridItem(.fixed(cardSize.width), spacing: interCardSpacing, alignment: .top), count: max(1, columns))
    }
    var body: some View {
        let previewHeight = max(100, cardSize.height - 92)
        return ScrollView(showsIndicators: false) {
            OffsetReportingSpacer(onOffsetChange: onScrollOffsetChanged)
            LazyVGrid(columns: gridItems, spacing: interCardSpacing) {
                ForEach(tabs) { tab in
                    SafariTabCard(
                        tab: tab,
                        isSelected: tab.id == selectedTabID,
                        previewHeight: previewHeight,
                        cardWidth: cardSize.width,
                        onSelect: onSelect,
                        onClose: onClose
                    )
                }
            }
            .padding(sectionInsets)
        }
        .safariScrollPhysics(.overview)
        .coordinateSpace(name: OffsetReportingSpacer.space)
    }
}

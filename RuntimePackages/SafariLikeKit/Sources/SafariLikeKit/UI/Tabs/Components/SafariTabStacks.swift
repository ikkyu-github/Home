import SwiftUI
import SafariLikeCoreKit
internal struct SafariTabPortraitStack: View {
    let tabs: [TabState]
    let tabGroups: [BrowserTabGroup]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let containerSize: CGSize
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onScrollOffsetChanged: ((CGFloat) -> Void)?
    private var cardHeight: CGFloat {
        min(180, max(140, containerSize.height * 0.25))
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            OffsetReportingSpacer(onOffsetChange: onScrollOffsetChanged)
            LazyVStack(spacing: 16) {
                ForEach(tabs) { tab in
                    SafariTabCard(
                        tab: tab,
                        isSelected: tab.id == selectedTabID,
                        previewHeight: cardHeight - 60,
                        cardWidth: nil,
                        onSelect: onSelect,
                        onClose: onClose
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .safariScrollPhysics(.overview)
        .coordinateSpace(name: OffsetReportingSpacer.space)
    }
}
internal struct SafariTabLandscapeGrid: View {
    let tabs: [TabState]
    let tabGroups: [BrowserTabGroup]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let containerSize: CGSize
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onScrollOffsetChanged: ((CGFloat) -> Void)?
    private var columns: [GridItem] {
        let columnCount = containerSize.width > 1000 ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    private var cardHeight: CGFloat {
        min(140, max(100, containerSize.height * 0.20))
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            OffsetReportingSpacer(onOffsetChange: onScrollOffsetChanged)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(tabs) { tab in
                    SafariTabCard(
                        tab: tab,
                        isSelected: tab.id == selectedTabID,
                        previewHeight: cardHeight - 50,
                        cardWidth: nil,
                        onSelect: onSelect,
                        onClose: onClose
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 110)
        }
        .safariScrollPhysics(.overview)
        .coordinateSpace(name: OffsetReportingSpacer.space)
    }
}
internal struct OffsetReportingSpacer: View {
    static let space = "tab_overview_scroll_space"
    let onOffsetChange: ((CGFloat) -> Void)?
    var body: some View {
        GeometryReader { proxy in
            let offset = -proxy.frame(in: .named(Self.space)).minY
            Color.clear
                .preference(key: ScrollOffsetPreferenceKey.self, value: offset)
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) {
            onOffsetChange?($0)
        }
    }
}
internal struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

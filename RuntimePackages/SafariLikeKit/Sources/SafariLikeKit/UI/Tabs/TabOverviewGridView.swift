import SwiftUI
import UIKit
import SafariLikeCoreKit
struct TabOverviewGridView: View {
    let progress: CGFloat
    let tabs: [TabState]
    let tabGroups: [BrowserTabGroup]
    let selectedTabID: UUID?
    let selectedTabGroupID: UUID?
    let onSelect: (UUID) -> Void
    let onClose: (UUID) -> Void
    let onNewTab: () -> Void
    let onDone: (() -> Void)?
    let onScrollOffsetChanged: ((CGFloat) -> Void)?
    init(
        progress: CGFloat,
        tabs: [TabState],
        tabGroups: [BrowserTabGroup],
        selectedTabID: UUID?,
        selectedTabGroupID: UUID?,
        onSelect: @escaping (UUID) -> Void,
        onClose: @escaping (UUID) -> Void,
        onNewTab: @escaping () -> Void,
        onDone: (() -> Void)? = nil,
        onScrollOffsetChanged: ((CGFloat) -> Void)? = nil
    ) {
        self.progress = progress
        self.tabs = tabs
        self.tabGroups = tabGroups
        self.selectedTabID = selectedTabID
        self.selectedTabGroupID = selectedTabGroupID
        self.onSelect = onSelect
        self.onClose = onClose
        self.onNewTab = onNewTab
        self.onDone = onDone
        self.onScrollOffsetChanged = onScrollOffsetChanged
    }
    var body: some View {
        SafariTabOverviewView(
            progress: progress,
            tabs: tabs,
            tabGroups: tabGroups,
            selectedTabID: selectedTabID,
            selectedTabGroupID: selectedTabGroupID,
            onSelect: onSelect,
            onClose: onClose,
            onNewTab: onNewTab,
            onDone: onDone,
            onScrollOffsetChanged: onScrollOffsetChanged
        )
    }
}

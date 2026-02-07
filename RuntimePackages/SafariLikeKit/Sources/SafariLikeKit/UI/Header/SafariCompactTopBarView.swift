import SwiftUI
import UniformTypeIdentifiers
import Foundation
import UIKit
import SafariLikeUXKit
import SafariLikeCoreKit
import SafariLikeContracts
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (large SwiftUI view + heavy imports).
// Keep imports minimal; push preview/debug helpers behind flags to reduce incremental rebuild work.
/// Safari iPad-style compact toolbar
/// - Gesture-safe in portrait (WKWebView friendly)
struct SafariCompactTopBarView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let style: BrowserChromeStyle
    let topBarMode: TopBarView.InteractionMode
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    @Environment(\.uxPolicy) private var uxPolicy
    @State private var containerWidth: CGFloat = 0
    @State private var isTabStripDropTargeted: Bool = false
    @State private var tabStripFrames: [UUID: CGRect] = [:]
    @State private var tabStripDraggingTabID: UUID? = nil
    @State private var tabStripDragTranslation: CGSize = .zero
    @Namespace private var tabSelectionNamespace
    private var chromePolicy: ChromePolicy {
        ChromePolicy.defaultPolicy(for: UITraitCollection.current)
    }
    init(
        vm: SplitBrowserViewModel,
        style: BrowserChromeStyle,
        topBarMode: TopBarView.InteractionMode = .interactive,
        isLandscape: Bool = false
    ) {
        self.vm = vm
        self.style = style
        self.topBarMode = topBarMode
    }
    // Backward-compatible init for existing call sites.
    init(
        vm: SplitBrowserViewModel,
        topBarMode: TopBarView.InteractionMode = .interactive,
        isLandscape: Bool = false
    ) {
        self.init(
            vm: vm,
            style: isLandscape ? .padLandscapeSafari : .phonePortraitSafari,
            topBarMode: topBarMode
        )
    }
    var body: some View {
        Group {
            if style == .padLandscapeSafari {
                padLandscapeChrome
            } else {
                phonePortraitChrome
            }
        }
    }
    // MARK: - Main Containers
    private var padLandscapeChrome: some View {
        VStack(spacing: 0) {
            toolbarRowPadLandscape(showSecondaryButtons: !chrome.chromeSnapshot.isCollapsed)
                .frame(height: 44)
            if vm.bar.addressBarViewState.isTextInputFocused == false {
                tabStripRowPadLandscape()
                    .frame(height: 44)
            }
        }
        .frame(
            height: SafariHeaderView.height(
                for: style,
                isEditing: (topBarMode == .interactive) && vm.bar.addressBarViewState.isTextInputFocused
            )
        )
        .background(containerWidthReader)
    }
    private var phonePortraitChrome: some View {
        PhonePortraitBottomBar(
            text: Binding(
                get: { vm.bar.addressBarViewState.textFieldText },
                set: { newValue in
                    vm.bar.send(SafariLikeContracts.AddressBarEvent.textChanged(newValue))
                }
            ),
            isEditing: Binding(
                get: { topBarMode == .interactive && vm.bar.addressBarViewState.isTextInputFocused },
                set: { newValue in
                    guard topBarMode == .interactive else { return }
                    if newValue {
                        vm.bar.send(SafariLikeContracts.AddressBarEvent.tapAddressBar)
                    } else {
                        vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                    }
                }
            ),
            onToggleSidebar: {
                withAnimation(SwiftUI.Animation.easeInOut(duration: 0.22)) {
                    vm.toggleSidebar()
                }
            },
            onToggleRelated: {
                toggleRelatedFromToolbar()
            },
            onPresentTabOverview: {
                vm.presentTabOverview()
            },
            onNewTab: {
                vm.newTab()
            },
            onBack: {
                vm.send(.goBack)
            },
            onForward: {
                vm.send(.goForward)
            },
            onReload: {
                if vm.isLoading {
                    vm.send(.stopLoading)
                } else {
                    vm.send(.reload)
                }
            },
            onSubmitURL: { submittedText in
                vm.bar.send(SafariLikeContracts.AddressBarEvent.textChanged(submittedText))
                vm.bar.send(SafariLikeContracts.AddressBarEvent.submitAndDismissEditing)
            },
            onAddBookmark: {
                vm.addBookmarkForActivePage()
            },
            onShare: {
                chrome.shareCurrentPage()
            }
        )
        .background(containerWidthReader)
    }
    private var phonePortraitEditingChrome: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
            }
            .foregroundStyle(.blue)
            RelatedButton {
                toggleRelatedFromToolbar()
            }
            TopBarView(vm: vm, mode: topBarMode, showsCancelButton: false)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
            Button("Done") {
                vm.bar.send(SafariLikeContracts.AddressBarEvent.submitAndDismissEditing)
            }
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .frame(height: SafariHeaderView.height(for: style))
        .contentShape(Rectangle())
    }
    private var phonePortraitToolbarChrome: some View {
        let isPhonePortraitStyle = true
        let isPadLandscapeStyle = false
        let showSecondaryButtons = (chrome.chromeSnapshot.isCollapsed == false)
        let scale: CGFloat = {
            let chromeHeight = chromePolicy.chromeHeightPolicy.currentHeight
            let targetHeight = chromePolicy.chromeHeightPolicy.maxHeight
            return max(0.5, min(1.0, chromeHeight / max(1, targetHeight)))
        }()
        return HStack(spacing: 10) {
            Button { vm.send(.goBack) } label: { Image(systemName: "chevron.left") }
                .disabled(!vm.canGoBack)
                .opacity(vm.canGoBack ? 1 : 0.35)
                .allowsHitTesting(true)
            Button { vm.send(.goForward) } label: { Image(systemName: "chevron.right") }
                .disabled(!vm.canGoForward)
                .opacity(vm.canGoForward ? 1 : 0.35)
                .allowsHitTesting(true)
            // URL bar gets higher layout priority to avoid being squeezed.
            TopBarView(vm: vm, mode: topBarMode)
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
                .allowsHitTesting(true)
            Button {
                if vm.isLoading {
                    vm.send(.stopLoading)
                } else {
                    vm.send(.reload)
                }
            } label: {
                Image(systemName: vm.isLoading ? "xmark" : "arrow.clockwise")
            }
            .allowsHitTesting(true)
            RelatedButton {
                toggleRelatedFromToolbar()
            }
            .allowsHitTesting(true)
            // Essential buttons must remain visible even when the chrome collapses.
            essentialButtons(
                isPhonePortraitStyle: isPhonePortraitStyle,
                isPadLandscapeStyle: isPadLandscapeStyle
            )
            if showSecondaryButtons {
                secondaryButtons(isPadLandscapeStyle: isPadLandscapeStyle)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: SafariHeaderView.height(for: style))
        .scaleEffect(scale, anchor: .center)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: chrome.chromeSnapshot.isCollapsed)
    }
    private var containerWidthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .allowsHitTesting(false)
                .onAppear { containerWidth = proxy.size.width }
                .onChange(of: proxy.size.width) { newValue in
                    containerWidth = newValue
                }
        }
    }
    // MARK: - iPad Landscape Rows
    private func toolbarRowPadLandscape(showSecondaryButtons: Bool) -> some View {
        BrowserToolbarView(relatedAction: { toggleRelatedFromToolbar() }) {
            // Sidebar (left)
            Button {
                withAnimation(SwiftUI.Animation.easeInOut(duration: 0.22)) {
                    vm.toggleSidebar()
                }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .allowsHitTesting(true)
            // Back / Forward
            Button {
                vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                vm.send(.goBack)
            } label: { Image(systemName: "chevron.left") }
                .disabled(!vm.canGoBack)
                .opacity(vm.canGoBack ? 1 : 0.35)
                .allowsHitTesting(true)
            Button {
                vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                vm.send(.goForward)
            } label: { Image(systemName: "chevron.right") }
                .disabled(!vm.canGoForward)
                .opacity(vm.canGoForward ? 1 : 0.35)
                .allowsHitTesting(true)
            // Address Bar (center)
            TopBarView(vm: vm, mode: topBarMode)
                .frame(maxWidth: .infinity)
                .layoutPriority(2)
                .allowsHitTesting(true)
            // Reload / Stop
            Button {
                vm.bar.send(SafariLikeContracts.AddressBarEvent.cancelEditing)
                if vm.isLoading {
                    vm.send(.stopLoading)
                } else {
                    vm.send(.reload)
                }
            } label: {
                Image(systemName: vm.isLoading ? "xmark" : "arrow.clockwise")
            }
            .allowsHitTesting(true)
            // Share
            Button { chrome.shareCurrentPage() } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .allowsHitTesting(true)
            // Downloads
            Button {
                chrome.downloads.refresh()
                chrome.isDownloadsPresented = true
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .allowsHitTesting(true)
            // Book / actions menu (preserve existing behavior)
            if showSecondaryButtons {
                essentialButtons(isPhonePortraitStyle: false, isPadLandscapeStyle: true)
            } else {
                // Still expose tab overview/new tab even when collapsed.
                if uxPolicy.tabOverview.isEnabled {
                    Button { vm.presentTabOverview() } label: { Image(systemName: "square.on.square") }
                        .accessibilityIdentifier("SafariLike.TopBar.TabOverview")
                        .allowsHitTesting(true)
                }
                Button { vm.newTab() } label: { Image(systemName: "plus") }
                    .accessibilityIdentifier("SafariLike.TopBar.NewTab")
                    .allowsHitTesting(true)
            }
            // Spin View Toggle (Split intent)
            let allowsSplitByWidth = containerWidth >= uxPolicy.splitBrowser.splitEnabledMinWidth
            Button {
                Diagnostics.logInfo("SplitButton tap width=\(containerWidth) allowsSplit=\(allowsSplitByWidth) mode=\(chrome.splitViewMode)", subsystem: .ui, category: "SplitView")
                if allowsSplitByWidth {
                    withAnimation(.easeOut(duration: 0.2)) {
                        chrome.splitViewMode = (chrome.splitViewMode == .single) ? .dual : .single
                    }
                } else {
                    AppWindowActions.openNewWindowIfSupported()
                }
            } label: {
                Image(
                    systemName: allowsSplitByWidth
                        ? (chrome.splitViewMode == .dual ? "xmark.rectangle" : "rectangle.split.2x1")
                        : "plus.rectangle.on.rectangle"
                )
                .accessibilityLabel(allowsSplitByWidth ? "Toggle Split View" : "Open New Window")
            }
            .allowsHitTesting(true)
        }
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .allowsHitTesting(true)
    }
    private func toggleRelatedFromToolbar() {
        Diagnostics.logInfo(
            "RelatedButton tap isVisible=\(relatedChrome.isVisible)",
            subsystem: .ui,
            category: "Related"
        )
    }
    private func tabStripRowPadLandscape() -> some View {
        let tabs = vm.tabs
        let shouldScroll = tabs.count >= 6
        return ZStack {
            if isTabStripDropTargeted {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
            Group {
                if shouldScroll {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(tabs) { tab in
                                TabStripInteractiveItem(
                                    tabID: tab.id,
                                    title: tab.title,
                                    urlString: tab.urlString,
                                    isSelected: tab.id == vm.activeTabID,
                                    selectionNamespace: tabSelectionNamespace,
                                    draggingTabID: $tabStripDraggingTabID,
                                    dragTranslation: $tabStripDragTranslation,
                                    frames: $tabStripFrames,
                                    orderedTabIDs: tabs.map(\.id),
                                    onSelect: { vm.selectTab(tab.id) },
                                    onClose: { vm.closeTab(tab.id) },
                                    onMove: { from, to in vm.moveTab(from: from, to: to) }
                                )
                                .frame(minWidth: 170, idealWidth: 220, maxWidth: 280)
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .safariScrollPhysics(.tabStrip)
                } else {
                    HStack(spacing: 8) {
                        ForEach(tabs) { tab in
                            TabStripInteractiveItem(
                                tabID: tab.id,
                                title: tab.title,
                                urlString: tab.urlString,
                                isSelected: tab.id == vm.activeTabID,
                                selectionNamespace: tabSelectionNamespace,
                                draggingTabID: $tabStripDraggingTabID,
                                dragTranslation: $tabStripDragTranslation,
                                frames: $tabStripFrames,
                                orderedTabIDs: tabs.map(\.id),
                                onSelect: { vm.selectTab(tab.id) },
                                onClose: { vm.closeTab(tab.id) },
                                onMove: { from, to in vm.moveTab(from: from, to: to) }
                            )
                            .frame(minWidth: 180, idealWidth: 240, maxWidth: 320)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(SafariMotion.spring, value: vm.activeTabID)
        .animation(SafariMotion.spring, value: vm.tabs.map(\.id))
        .animation(SafariMotion.spring, value: isTabStripDropTargeted)
        // ✋ Drag & Drop: drop a Related item to open it as a brand-new tab.
        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: $isTabStripDropTargeted) { providers in
            handleTabStripDrop(providers)
        }
    }
    private func handleTabStripDrop(_ providers: [NSItemProvider]) -> Bool {
        let provider = providers.first
        guard let provider else { return false }
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    openDroppedURLString(url.absoluteString)
                } else if let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) {
                    openDroppedURLString(url.absoluteString)
                }
            }
            return true
        }
        provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
            if let s = item as? String, !s.isEmpty {
                openDroppedURLString(s)
            } else if let data = item as? Data, let s = String(data: data, encoding: .utf8), !s.isEmpty {
                openDroppedURLString(s)
            }
        }
        return true
    }
    private func openDroppedURLString(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.18)) {
                vm.openTab(urlString: trimmed, inBackground: false)
            }
        }
    }
    // MARK: - Buttons
    @ViewBuilder
    private func essentialButtons(
        isPhonePortraitStyle: Bool,
        isPadLandscapeStyle: Bool
    ) -> some View {
        Menu {
            Button {
                chrome.isFindBarPresented = true
            } label: {
                Label("Find on Page", systemImage: "magnifyingglass")
            }
            Menu {
                Button {
                    chrome.setTextScalePercent(chrome.textScalePercent - 10)
                } label: {
                    Label("Smaller Text", systemImage: "textformat.size.smaller")
                }
                Button {
                    chrome.setTextScalePercent(chrome.textScalePercent + 10)
                } label: {
                    Label("Larger Text", systemImage: "textformat.size.larger")
                }
                Button {
                    chrome.setTextScalePercent(100)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Label("Text Size", systemImage: "textformat.size")
            }
            Button {
                chrome.toggleReaderMode()
            } label: {
                Label(chrome.isReaderEnabled ? "Reader: On" : "Reader: Off", systemImage: "doc.text")
            }
            .disabled(!chrome.isReaderAvailable)
            Button {
                chrome.shareCurrentPageAsPDF()
            } label: {
                Label("Share as PDF", systemImage: "doc.richtext")
            }
            Button {
                vm.togglePrivateMode()
            } label: {
                Label(vm.isPrivateMode ? "Exit Private Mode" : "Private Mode", systemImage: vm.isPrivateMode ? "eye.slash" : "eye")
            }
            Divider()
            Button {
                vm.addBookmarkForActivePage()
            } label: {
                Label("Add Bookmark", systemImage: "bookmark")
            }
            Button {
                vm.addToReadingListForActivePage()
            } label: {
                Label("Add to Reading List", systemImage: "eyeglasses")
            }
            Button {
                chrome.isWebsiteSettingsPresented = true
            } label: {
                Label("Website Settings", systemImage: "gear")
            }
            Divider()
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    vm.toggleSidebar()
                }
            } label: {
                Label("Open Library", systemImage: "book")
            }
            if isPhonePortraitStyle {
                Button {
                    chrome.downloads.refresh()
                    chrome.isDownloadsPresented = true
                } label: {
                    Label("Downloads", systemImage: "arrow.down.circle")
                }
            }
            Divider()
            Button {
                AppWindowActions.openNewWindowIfSupported()
            } label: {
                Label("New Window", systemImage: "plus.rectangle")
            }
            if isPhonePortraitStyle {
                let allowsSplitByWidth = containerWidth >= uxPolicy.splitBrowser.splitEnabledMinWidth
                Button {
                    Diagnostics.logInfo("SplitButton tap width=\(containerWidth) allowsSplit=\(allowsSplitByWidth) mode=\(chrome.splitViewMode)", subsystem: .ui, category: "SplitView")
                    if allowsSplitByWidth {
                        withAnimation(.easeOut(duration: 0.2)) {
                            chrome.splitViewMode =
                                (chrome.splitViewMode == .single) ? .dual : .single
                        }
                    } else {
                        AppWindowActions.openNewWindowIfSupported()
                    }
                } label: {
                    Label(
                        allowsSplitByWidth ? "Toggle Split View" : "Open New Window",
                        systemImage: allowsSplitByWidth
                            ? (chrome.splitViewMode == .dual ? "xmark.rectangle" : "rectangle.split.2x1")
                            : "plus.rectangle.on.rectangle"
                    )
                }
            }
        } label: {
            Image(systemName: "book")
        }
        .allowsHitTesting(true)
        if uxPolicy.tabOverview.isEnabled {
            Button { vm.presentTabOverview() } label: {
                Image(systemName: "square.on.square")
            }
            .allowsHitTesting(true)
        }
        Button { vm.newTab() } label: {
            Image(systemName: "plus")
        }
        .allowsHitTesting(true)
    }
    @ViewBuilder
    private func secondaryButtons(isPadLandscapeStyle: Bool) -> some View {
        Button {
            chrome.shareCurrentPage()
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .allowsHitTesting(true)
        if isPadLandscapeStyle {
            Button {
                chrome.downloads.refresh()
                chrome.isDownloadsPresented = true
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .allowsHitTesting(true)
            let allowsSplitByWidth = containerWidth >= uxPolicy.splitBrowser.splitEnabledMinWidth
            Button {
                Diagnostics.logInfo("SplitButton tap width=\(containerWidth) allowsSplit=\(allowsSplitByWidth) mode=\(chrome.splitViewMode)", subsystem: .ui, category: "SplitView")
                if allowsSplitByWidth {
                    withAnimation(.easeOut(duration: 0.2)) {
                        chrome.splitViewMode =
                            (chrome.splitViewMode == .single) ? .dual : .single
                    }
                } else {
                    AppWindowActions.openNewWindowIfSupported()
                }
            } label: {
                Image(
                    systemName: allowsSplitByWidth
                        ? (chrome.splitViewMode == .dual ? "xmark.rectangle" : "rectangle.split.2x1")
                        : "plus.rectangle.on.rectangle"
                )
                .accessibilityLabel(allowsSplitByWidth ? "Toggle Split View" : "Open New Window")
            }
            .allowsHitTesting(true)
        }
    }
    // MARK: - Tabs
    private func tabPillsBar() -> some View {
        let pillSpacing: CGFloat = 6
        return GeometryReader { proxy in
            let availableWidth = max(0, proxy.size.width)
            let count = max(1, vm.tabs.count)
            let pillWidth = max(52, (availableWidth - CGFloat(count - 1) * pillSpacing) / CGFloat(count))
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: pillSpacing) {
                    ForEach(vm.tabs) { tab in
                        CompactTabPill(
                            title: tab.title,
                            urlString: tab.urlString,
                            isSelected: tab.id == vm.activeTabID,
                            width: pillWidth,
                            showClose: pillWidth >= 70,
                            onSelect: { self.vm.selectTab(tab.id) },
                            onClose: { vm.closeTab(tab.id) }
                        )
                    }
                }
                .padding(.horizontal, 6)
            }
            .safariScrollPhysics(.tabStrip)
        }
        .frame(maxWidth: .infinity)
        // ✋ Drag & Drop: drop a Related item to open it as a brand-new tab.
        .onDrop(of: [UTType.url, UTType.plainText], isTargeted: nil) { providers in
            let provider = providers.first
            guard let provider else { return false }
                    if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        Task { @MainActor in
                                    self.vm.newTab()
                                    self.vm.send(.openURLStringForce(url.absoluteString))
                        }
                    } else if let data = item as? Data,
                              let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                                    self.vm.newTab()
                                    self.vm.send(.openURLStringForce(url.absoluteString))
                        }
                    }
                }
                return true
            }
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                if let s = item as? String, !s.isEmpty {
                    Task { @MainActor in
                        self.vm.newTab()
                        self.vm.send(.openURLStringForce(s))
                    }
                } else if let data = item as? Data, let s = String(data: data, encoding: .utf8), !s.isEmpty {
                    Task { @MainActor in
                        self.vm.newTab()
                        self.vm.send(.openURLStringForce(s))
                    }
                }
            }
            return true
        }
        // ❌ REMOVED: simultaneousGesture(DragGesture()) - This was causing conflicts with ScrollView's pan gestures
        // The ScrollView already handles horizontal scrolling properly, and adding a simultaneous drag gesture
        // on top can cause stuttering and gesture recognition issues. WebView gesture conflicts are better
        // handled at the WKWebView level, not by blanket gesture overrides.
    }
}
// MARK: - Subviews

private struct _TabStripItemFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

private struct TabStripInteractiveItem: View {
    let tabID: UUID
    let title: String
    let urlString: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID

    @Binding var draggingTabID: UUID?
    @Binding var dragTranslation: CGSize
    @Binding var frames: [UUID: CGRect]

    let orderedTabIDs: [UUID]
    let onSelect: () -> Void
    let onClose: () -> Void
    let onMove: (_ from: Int, _ to: Int) -> Void

    @State private var swipeOffsetX: CGFloat = 0
    @State private var isClosingBySwipe: Bool = false

    private var isDraggingSelf: Bool { draggingTabID == tabID }

    var body: some View {
        SafariTabStripItem(
            title: title,
            urlString: urlString,
            isSelected: isSelected,
            selectionNamespace: selectionNamespace,
            onSelect: onSelect,
            onClose: onClose
        )
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: _TabStripItemFramePreferenceKey.self, value: [tabID: proxy.frame(in: .global)])
            }
        )
        .onPreferenceChange(_TabStripItemFramePreferenceKey.self) { pref in
            frames.merge(pref, uniquingKeysWith: { $1 })
        }
        .offset(x: isDraggingSelf ? dragTranslation.width : swipeOffsetX, y: isDraggingSelf ? dragTranslation.height * 0.1 : 0)
        .zIndex(isDraggingSelf ? 10 : 0)
        .scaleEffect(isDraggingSelf ? 1.02 : 1)
        .simultaneousGesture(reorderGesture)
        .simultaneousGesture(swipeToCloseGesture)
    }

    private var reorderGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.18)
            .sequenced(before: DragGesture(minimumDistance: 1, coordinateSpace: .global))
            .onChanged { value in
                switch value {
                case .first(true):
                    if draggingTabID == nil {
                        draggingTabID = tabID
                        dragTranslation = .zero
                        #if os(iOS)
                        if UIAccessibility.isReduceMotionEnabled == false {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.prepare()
                            gen.impactOccurred(intensity: 0.55)
                        }
                        #endif
                    }
                case .second(true, let drag?):
                    guard isDraggingSelf else { return }
                    dragTranslation = drag.translation
                    maybeReorder(for: drag)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard isDraggingSelf else { return }
                withAnimation(SafariMotion.spring) {
                    dragTranslation = .zero
                }
                draggingTabID = nil
            }
    }

    private func maybeReorder(for drag: DragGesture.Value) {
        guard let selfFrame = frames[tabID] else { return }
        guard let from = orderedTabIDs.firstIndex(of: tabID) else { return }

        let currentCenterX = selfFrame.midX + drag.translation.width
        var nearestIndex = from
        var nearestDistance = CGFloat.greatestFiniteMagnitude

        for (idx, id) in orderedTabIDs.enumerated() {
            guard let frame = frames[id] else { continue }
            let d = abs(frame.midX - currentCenterX)
            if d < nearestDistance {
                nearestDistance = d
                nearestIndex = idx
            }
        }
        guard nearestIndex != from else { return }
        withAnimation(SafariMotion.spring) {
            onMove(from, nearestIndex)
        }
    }

    private var swipeToCloseGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard draggingTabID == nil else { return }
                guard isClosingBySwipe == false else { return }

                let dx = value.translation.width
                let dy = value.translation.height
                guard dx < 0, abs(dy) < 22 else {
                    swipeOffsetX = 0
                    return
                }
                swipeOffsetX = max(-120, dx * 0.55)
            }
            .onEnded { value in
                guard draggingTabID == nil else {
                    swipeOffsetX = 0
                    return
                }
                let dx = value.translation.width
                let predicted = value.predictedEndTranslation.width
                let dy = value.translation.height
                guard dx < 0, abs(dy) < 22 else {
                    withAnimation(SafariMotion.spring) { swipeOffsetX = 0 }
                    return
                }

                let baseThreshold: CGFloat = isSelected ? 120 : 88
                let predictedThreshold: CGFloat = isSelected ? 180 : 140
                let shouldClose = (abs(dx) > baseThreshold) || (abs(predicted) > predictedThreshold)
                if shouldClose {
                    isClosingBySwipe = true
                    withAnimation(.easeInOut(duration: 0.12)) {
                        swipeOffsetX = -180
                    }
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 80_000_000)
                        onClose()
                        isClosingBySwipe = false
                        swipeOffsetX = 0
                    }
                } else {
                    withAnimation(SafariMotion.spring) {
                        swipeOffsetX = 0
                    }
                }
            }
    }
}

private struct SafariTabStripItem: View {
    let title: String
    let urlString: String
    let isSelected: Bool
    let selectionNamespace: Namespace.ID
    let onSelect: () -> Void
    let onClose: () -> Void
    @Environment(\.uxPolicy) private var uxPolicy
    private var displayTitle: String {
        title.isEmpty ? uxPolicy.strings.newTabTitle : title
    }
    private var hostInitial: String? {
        guard let url = URL(string: urlString), let host = url.host, let first = host.first else { return nil }
        return String(first).uppercased()
    }
    @State private var isHovered: Bool = false
    var body: some View {
        ZStack(alignment: .trailing) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.white.opacity(isSelected ? 0.20 : 0.10))
                        if let hostInitial {
                            Text(hostInitial)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.85))
                        } else {
                            Image(systemName: "globe")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.75))
                        }
                    }
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                    Text(displayTitle)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    // Reserve space for close button.
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(height: 32)
                .background {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                        if isSelected {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.16))
                                .matchedGeometryEffect(id: "tabStrip.selection", in: selectionNamespace)
                        }
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(isHovered ? 0.05 : 0))
                            .allowsHitTesting(false)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(isSelected ? 0.26 : 0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(isSelected ? 0.20 : 0.08), radius: isSelected ? 10 : 6, y: 3)
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(SafariPressableScaleButtonStyle())
            .onHover { hovering in
                withAnimation(.linear(duration: 0.12)) { isHovered = hovering }
            }
            .hoverEffect(.highlight)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 6)
            .accessibilityLabel("Close Tab")
        }
    }
}

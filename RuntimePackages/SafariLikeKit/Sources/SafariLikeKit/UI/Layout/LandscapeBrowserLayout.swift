import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
typealias SidebarItem = SidebarView.Item
/// Helper view to set chrome height limits
private struct SetChromeLimits: View {
    let minHeight: CGFloat
    let maxHeight: CGFloat
    @EnvironmentObject var chrome: BrowserChromeState
    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .onAppear {
                chrome.minChromeHeight = minHeight
                chrome.maxChromeHeight = maxHeight
            }
    }
}
internal struct LandscapeBrowserLayout: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let configuration: SafariLikeConfiguration
    let chromeStyle: BrowserChromeStyle
    let containerSize: CGSize
    let safeAreaInsets: EdgeInsets
    let browserRootWidth: CGFloat
    let onSidebarSelect: (SidebarItem) -> Void
    @EnvironmentObject private var chrome: BrowserChromeState
    @Environment(\.isLayoutStabilizing) private var isLayoutStabilizing
    private var activeTabState: BrowserTab.State? {
        let id = vm.activeTabID ?? vm.sessionStore.selectedTabID
        guard let id else { return nil }
        return vm.sessionStore.tabs.first(where: { $0.id == id })?.state
    }
    var body: some View {
        let headerHeight = SafariHeaderView.height(for: chromeStyle)
        let shouldShowWebContent = vm.shouldShowWebContentForActiveTab
        let safeWidth: CGFloat = max(0, containerSize.width - safeAreaInsets.leading - safeAreaInsets.trailing)
        #if DEBUG
        // HARD DEBUG (ห้ามลบ): in landscape, WebView must always get full safe width.
        let contentWidth: CGFloat = safeWidth
        let safeW = String(format: "%.1f", safeWidth)
        let contentW = String(format: "%.1f", contentWidth)
        let sidebarW = String(format: "%.1f", 0)
        let hardLayoutLogLine =
            "[HARD][LAYOUT] MODE=landscape " +
            "sidebarVisible=\(vm.isSidebarVisible) " +
            "SAFE=\(safeW) " +
            "CONTENT=\(contentW) " +
            "SIDEBAR=\(sidebarW)" // ห้ามลบ
        #endif
        // Layout contract: do not ignore safe areas for web/content containers.
        // Content already lives inside safe areas, so avoid adding extra manual padding.
        // In landscape on iPhone, leading/trailing safe insets are critical for chrome hit-testing.
        let contentLeadingSafe: CGFloat = max(0, safeAreaInsets.leading)
        let contentTrailingSafe: CGFloat = max(0, safeAreaInsets.trailing)
        let contentTopSafe: CGFloat = 0
        let contentBottomSafe: CGFloat = 0
        let base = ZStack(alignment: .topLeading) {
            // MARK: - Main Content Area (header moves together with WebView)
            VStack(spacing: 0) {
                SafariHeaderView(
                    vm: vm,
                    style: chromeStyle,
                    topBarMode: .interactive,
                    leadingSafeAreaPadding: contentLeadingSafe,
                    trailingSafeAreaPadding: contentTrailingSafe
                )
                .frame(height: headerHeight)
                .zIndex(1000)
                TabRenderer(
                    tabState: activeTabState,
                    preferWebContent: shouldShowWebContent,
                    startPage: {
                        StartPageLandscapeView(
                            bookmarkStore: vm.bookmarkStore,
                            leadingSafePadding: contentLeadingSafe,
                            trailingSafePadding: contentTrailingSafe,
                            onOpenURLString: { urlString in
                                vm.send(.openURLString(urlString))
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    },
                    web: {
                        ZStack {
                            if let handle = vm.activeWebViewHandleForRendering {
                                LandscapeWebPane(
                                    webViewHandle: handle,
                                    vm: vm,
                                    chromeStyle: chromeStyle,
                                    contentLeadingSafe: contentLeadingSafe,
                                    contentTrailingSafe: contentTrailingSafe,
                                    contentTopSafe: contentTopSafe,
                                    contentBottomSafe: contentBottomSafe,
                                    headerHeight: headerHeight
                                )
                            } else if vm.sessionStore.tabs.isEmpty {
                                EmptyBrowserPane(onNewTab: { vm.newTab() })
                            } else {
                                // White page is acceptable while attaching.
                                Color(.systemBackground)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .overlay {
                            // Launching overlay: must not replace the WebView and must not animate chrome.
                            if shouldShowWebContent == false, (vm.activeWebViewHandleForRendering?.isAlive != true) {
                                LaunchingBrowserPane(title: "Launching…", subtitle: "Attaching WebView")
                                    .allowsHitTesting(false)
                                    .transaction { $0.animation = nil }
                            }
                        }
                        .transaction { txn in
                            txn.animation = nil
                        }
                    },
                    empty: {
                        EmptyBrowserPane(onNewTab: { vm.newTab() })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            if vm.isSidebarVisible {
                SidebarOverlay(
                    isVisible: Binding(
                        get: { vm.isSidebarVisible },
                        set: { isVisible in
                            vm.setSidebarVisible(isVisible)
                        }
                    ),
                    width: configuration.sidebarWidth,
                    viewModel: vm,
                    onSelect: onSidebarSelect
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            SetChromeLimits(minHeight: headerHeight, maxHeight: headerHeight)
                .frame(width: 0, height: 0)
        )
        #if DEBUG
        return base
            .onAppear {
                print(hardLayoutLogLine)
            }
            .onChange(of: safeWidth) { _ in
                print(hardLayoutLogLine)
            }
            .onChange(of: vm.isSidebarVisible) { _ in
                print(hardLayoutLogLine)
            }
        #else
        return base
        #endif
    }
}
private struct LandscapeWebPane: View {
    let webViewHandle: WebViewHandle
    @ObservedObject var vm: SplitBrowserViewModel
    @EnvironmentObject private var chrome: BrowserChromeState
    @Environment(\.uxPolicy) private var uxPolicy
    let chromeStyle: BrowserChromeStyle
    let contentLeadingSafe: CGFloat
    let contentTrailingSafe: CGFloat
    let contentTopSafe: CGFloat
    let contentBottomSafe: CGFloat
    let headerHeight: CGFloat
    var body: some View {
        Group {
            if let tabID = vm.activeTabID {
                WebView(
                    webViewHandle: webViewHandle,
                    realityUpdater: vm.runtimeRealityUpdaterIfAlive(for: tabID),
                    headerView: SafariHeaderView(
                        vm: vm,
                        style: chromeStyle,
                        topBarMode: .passive,
                        leadingSafeAreaPadding: contentLeadingSafe,
                        trailingSafeAreaPadding: contentTrailingSafe
                    ),
                    topContentInset: 0,
                    bottomContentInset: 0,
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
                    onFocus: { vm.setActivePane(.left) },
                    edgeSwipePolicy: uxPolicy.swipeNavigation
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            } else {
                Color.clear
            }
        }
    }
}

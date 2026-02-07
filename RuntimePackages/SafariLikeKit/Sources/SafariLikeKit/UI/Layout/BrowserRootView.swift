import SwiftUI
import SafariLikeCoreKit
/// Fullscreen browser root.
///
/// Contract:
/// - The browser canvas (WKWebView) must always remain full-bleed.
/// - Related presentation is driven by `RelatedPresentationMode`:
///   - `.sidePane` mounts Related as a secondary pane (HStack) with fixed width.
///   - otherwise, the WebView occupies the full width and Related is not part of the main layout tree.
/// - Split UI must not be used for the browser canvas.
internal struct BrowserRootView: View {
    private let viewModel: SplitBrowserViewModel
    @ObservedObject private var chrome: BrowserChromeState
    private let configuration: SafariLikeConfiguration
    private let makeSettingsView: (() -> AnyView)?

    @StateObject private var tabOverviewTransition = TabOverviewTransitionController()

    init(
        viewModel: SplitBrowserViewModel,
        chrome: BrowserChromeState,
        configuration: SafariLikeConfiguration,
        makeSettingsView: (() -> AnyView)?
    ) {
        self.viewModel = viewModel
        self.chrome = chrome
        self.configuration = configuration
        self.makeSettingsView = makeSettingsView
    }
    var body: some View {
        BrowserView(
            vm: viewModel,
            safeAreaInsets: EdgeInsets(),
            configuration: configuration,
            onSidebarSelect: { item in
                viewModel.glue.handleSidebarSelect(item)
            }
        )
        .environmentObject(chrome)
        .environmentObject(tabOverviewTransition)
        .sheet(isPresented: $chrome.isAppSettingsPresented) {
            if let makeSettingsView {
                makeSettingsView()
            } else {
                EmptyView()
            }
        }
        .sheet(isPresented: $chrome.isDownloadsPresented) {
            DownloadsPopoverView(chrome: chrome)
        }
    }
}

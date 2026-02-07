import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
/// Centralized chrome presenter driven only by `BrowserLayoutMode`.
internal struct BrowserChromeView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var sceneMetrics: SceneMetrics
    @Environment(\.browserLayoutMode) private var layoutMode
    var body: some View {
        let insetsUI = (sceneMetrics.stableInsets != .zero) ? sceneMetrics.stableInsets : UIEdgeInsets.zero
        let style: BrowserChromeStyle = (layoutMode == .tabletLandscape)
            ? .padLandscapeSafari
            : .phonePortraitSafari
        let header = SafariHeaderView(
            vm: vm,
            style: style,
            topBarMode: .interactive,
            leadingSafeAreaPadding: insetsUI.left,
            trailingSafeAreaPadding: insetsUI.right
        )
        switch layoutMode {
        case .phonePortrait:
            let alpha = max(0.5, chrome.interaction.chromeHeight / max(1, chrome.interaction.maxChromeHeight))
            header
                .frame(height: chrome.interaction.chromeHeight)
                .opacity(alpha)
                .padding(.bottom, insetsUI.bottom)
                .frame(maxWidth: .infinity, alignment: .bottom)
        case .tabletLandscape:
            header
                .padding(.top, insetsUI.top)
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}

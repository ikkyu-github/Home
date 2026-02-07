import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
import SafariLikeContracts
/// Safari iPad-like compact header
internal struct SafariHeaderView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    /// Controls whether the address bar is interactive or display-only
    /// - `.interactive`: can request address focus (ONLY one instance should use this)
    /// - `.passive`: display only, must NEVER request focus
    let topBarMode: TopBarView.InteractionMode
    let style: BrowserChromeStyle
    /// Insets chrome controls inside the safe area while keeping the background full-bleed.
    private let leadingSafeAreaPadding: CGFloat
    private let trailingSafeAreaPadding: CGFloat
    @EnvironmentObject private var chrome: BrowserChromeState
    @EnvironmentObject private var tabOverviewTransition: TabOverviewTransitionController
    @Environment(\.uxPolicy) private var uxPolicy
    @State private var isOverviewDragActive: Bool = false
    // MARK: - Layout constants (used by LandscapeBrowserLayout)
    /// Height of the chrome area (excludes optional Find bar).
    static func height(for style: BrowserChromeStyle) -> CGFloat {
        // Backward-compatible behavior for call sites that don't have editing context.
        // Treat as the non-editing (max) height.
        Self.height(for: style, isEditing: false)
    }

    /// Height of the chrome area (excludes optional Find bar), with editing state.
    /// - Note: In iPad landscape Safari-like chrome, omnibox editing hides the tab strip.
    static func height(for style: BrowserChromeStyle, isEditing: Bool) -> CGFloat {
        switch style {
        case .padLandscapeSafari:
            // Safari iPad landscape:
            // - editing: toolbar only (44)
            // - not editing: toolbar (44) + tab strip (44)
            return isEditing ? 44 : 88
        case .phonePortraitSafari:
            return 56
        }
    }
    /// Height reserved for the optional Find bar.
    static let findBarHeight: CGFloat = 56
    // MARK: - Init (backward compatible)
    init(
        vm: SplitBrowserViewModel,
        style: BrowserChromeStyle,
        topBarMode: TopBarView.InteractionMode = .interactive,
        isLandscape: Bool = false,
        leadingSafeAreaPadding: CGFloat = 0,
        trailingSafeAreaPadding: CGFloat = 0
    ) {
        self.vm = vm
        self.topBarMode = topBarMode
        self.style = style
        self.leadingSafeAreaPadding = leadingSafeAreaPadding
        self.trailingSafeAreaPadding = trailingSafeAreaPadding
    }
    // Backward-compatible init for existing call sites (maps to a style).
    init(
        vm: SplitBrowserViewModel,
        topBarMode: TopBarView.InteractionMode = .interactive,
        isLandscape: Bool = false
    ) {
        self.init(
            vm: vm,
            style: isLandscape ? .padLandscapeSafari : .phonePortraitSafari,
            topBarMode: topBarMode,
            leadingSafeAreaPadding: 0,
            trailingSafeAreaPadding: 0
        )
    }
    var body: some View {
        let isTopChrome: Bool = (style == .padLandscapeSafari)
        let isEditing = (topBarMode == .interactive) && vm.bar.addressBarViewState.isTextInputFocused
        let headerHeight = Self.height(
            for: style,
            isEditing: isEditing
        )
        VStack(spacing: 0) {
            SafariCompactTopBarView(
                vm: vm,
                style: style,
                topBarMode: topBarMode
            )
            .padding(.leading, leadingSafeAreaPadding)
            .padding(.trailing, trailingSafeAreaPadding)
            .frame(height: headerHeight)
            .contentShape(Rectangle())  // ✅ Safari-like hit-testing: blocks WKWebView
            .allowsHitTesting(true)     // ✅ Explicitly allow touches on chrome
            if chrome.isFindBarPresented && topBarMode == .interactive {
                FindOnPageBarView(chrome: chrome)
                    .padding(.leading, leadingSafeAreaPadding)
                    .padding(.trailing, trailingSafeAreaPadding)
                    .frame(height: Self.findBarHeight)
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)  // ✅ Entire header is gesture-safe
        .clipped()
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.22))
                        .blendMode(.overlay)
                )
        )
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1),
            alignment: .top
        )
        // Safari-like gesture: show tab overview from the chrome.
        // - Landscape (top bar): swipe down.
        // - Portrait (bottom bar): swipe up.
        // Placing this on the chrome avoids conflicts with pull-to-refresh in WKWebView.
        .simultaneousGesture(
            DragGesture(minimumDistance: uxPolicy.gestures.tabOverviewFromChromeMinimumDistance, coordinateSpace: .local)
                .onChanged { value in
                    guard topBarMode == .interactive else { return }
                    guard uxPolicy.gestures.isTabOverviewFromChromeEnabled else { return }
                    guard chrome.isFindBarPresented == false else { return }
                    guard isEditing == false else { return }
                    guard vm.isTabOverviewVisible == false else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dy) > abs(dx) else { return }
                    // Only treat the gesture as an opening gesture in the expected direction.
                    if isTopChrome {
                        guard dy > 0 else { return }
                    } else {
                        guard dy < 0 else { return }
                    }
                    if isOverviewDragActive == false {
                        isOverviewDragActive = true
                        tabOverviewTransition.beginDrag(source: .chrome(isTopChrome: isTopChrome))
                    }
                    tabOverviewTransition.updateDrag(
                        source: .chrome(isTopChrome: isTopChrome),
                        translation: dy,
                        predictedEndTranslation: value.predictedEndTranslation.height
                    )
                }
                .onEnded { value in
                    guard isOverviewDragActive else { return }
                    isOverviewDragActive = false
                    tabOverviewTransition.endDrag(
                        source: .chrome(isTopChrome: isTopChrome),
                        translation: value.translation.height,
                        predictedEndTranslation: value.predictedEndTranslation.height
                    )
                }
        , including: .gesture)
        .debugTouchInspector()
    }
}

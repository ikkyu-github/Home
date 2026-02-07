import SwiftUI
import SafariLikeCoreKit
/// Centralized layout and chrome policy for the browser UI.
///
/// Marked @MainActor because it coordinates UIKit/SwiftUI-facing
/// state exclusively on the main thread. All methods are synchronous
/// and must only be called from the main actor.
@MainActor
internal struct ChromeController {
    enum LayoutKind {
        case portrait
        case landscape
    }
    /// Determine the layout kind (portrait vs landscape) for a given size.
    static func layoutKind(for size: CGSize) -> LayoutKind {
        switch BrowserLayoutResolver.orientation(for: size) {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        }
    }
    /// Compute effective safe area insets, preferring explicit insets when non-zero.
    static func effectiveSafeAreaInsets(
        provided: EdgeInsets,
        geometryInsets: EdgeInsets
    ) -> EdgeInsets {
        EdgeInsets(
            top: provided.top > 0 ? provided.top : geometryInsets.top,
            leading: provided.leading > 0 ? provided.leading : geometryInsets.leading,
            bottom: provided.bottom > 0 ? provided.bottom : geometryInsets.bottom,
            trailing: provided.trailing > 0 ? provided.trailing : geometryInsets.trailing
        )
    }
    /// Apply initial chrome and orientation policy when the browser view appears.
    static func handleInitialAppear(
        viewModel: SplitBrowserViewModel,
        chrome: BrowserChromeState,
        chromeStyle: BrowserChromeStyle
    ) {
        // Reset companion-related state on first appearance.
        viewModel.didUserOverrideCompanionVisibility = false
        viewModel.isCompanionVisible = false
        // Apply orientation rule based on the current layout.
        viewModel.applyOrientationRule(isLandscape: chromeStyle == .padLandscapeSafari)
        chrome.setChromeStyle(chromeStyle)
        // Safari iPad landscape: never collapses (fixed 2-row height).
        if chromeStyle == .padLandscapeSafari {
            let headerHeight = SafariHeaderView.height(for: chromeStyle)
            chrome.interaction.minChromeHeight = headerHeight
            chrome.interaction.maxChromeHeight = headerHeight
            chrome.interaction.chromeHeight = headerHeight
        }
    }
    /// Respond to container size changes by updating orientation rules.
    static func handleSizeChange(
        viewModel: SplitBrowserViewModel,
        chrome: BrowserChromeState,
        newSize: CGSize,
        chromeStyle: BrowserChromeStyle
    ) {
        let isLandscape = layoutKind(for: newSize) == .landscape
        viewModel.applyOrientationRule(isLandscape: isLandscape)
        chrome.setChromeStyle(chromeStyle)
        // Safari iPad landscape: never collapses (fixed 2-row height).
        if chromeStyle == .padLandscapeSafari {
            let headerHeight = SafariHeaderView.height(for: chromeStyle)
            chrome.interaction.minChromeHeight = headerHeight
            chrome.interaction.maxChromeHeight = headerHeight
            chrome.interaction.chromeHeight = headerHeight
        }
    }
    /// Keyboard lift policy for the chrome / URL bar.
    ///
    /// This keeps the focus-only lift behavior aligned with Safari:
    /// lift only when the URL bar is focused.
    static func keyboardLift(
        isURLBarFocused: Bool,
        keyboardHeight: CGFloat
    ) -> CGFloat {
        isURLBarFocused ? keyboardHeight : 0
    }
}

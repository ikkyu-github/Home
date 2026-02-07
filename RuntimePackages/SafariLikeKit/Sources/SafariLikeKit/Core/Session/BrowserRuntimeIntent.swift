import Foundation

/// Single public runtime API surface for UI/App code.
///
/// UI emits intents; the runtime decides and mutates internal state.
public enum BrowserRuntimeIntent: Sendable {
    // MARK: - Navigation
    case openExternalURL(URL)
    case goBack
    case goForward
    case reload
    case stopLoading

    /// Opens a new tab (optionally with a URL string).
    ///
    /// Intended for UI/App code; the runtime decides how to apply it.
    case newTab(urlString: String? = nil, inBackground: Bool = false)
    case selectTab(UUID)
    case closeTab(UUID)

    // MARK: - Chrome / UI Modes
    case focusAddressBar
    case setTabOverviewVisible(Bool)
    /// Mirrors Tab Overview transition progress into runtime budgeting.
    ///
    /// Pass values in the range [0, 1].
    case setTabOverviewPresentationProgress(Double)
    case setSidebarVisible(Bool)
    case toggleRelated
    case setRelatedVisible(Bool)
    case setSplitViewEnabled(Bool)

    /// Mirrors window/pane geometry into runtime policy.
    case updateVisiblePaneMetrics(
        containerWidth: Double,
        containerHeight: Double,
        safeInsetsWidth: Double,
        safeInsetsHeight: Double
    )

    // MARK: - Session lifecycle
    case persistSessionNow
    case invalidateSession

    // MARK: - Plugins
    case enablePlugin(id: String)
    case disablePlugin(id: String)
}

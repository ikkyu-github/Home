import Foundation

/// Per-scene WebView budget configuration.
///
/// This is owned and applied by `SceneRuntimeContext`.
public struct WebViewBudget: Sendable, Equatable {
    public struct ProfileBudget: Sendable, Equatable {
        /// Maximum number of live `WKWebView` instances allowed for this profile.
        ///
        /// "Live" includes both leased and idle (warm) instances in the `WebViewPool`.
        public var maxLiveWebViews: Int

        /// Maximum number of concurrently active/attachable web views.
        ///
        /// In practice this corresponds to the render budget (e.g. split panes).
        public var maxConcurrentActiveWebViews: Int

        public init(maxLiveWebViews: Int, maxConcurrentActiveWebViews: Int) {
            self.maxLiveWebViews = max(1, maxLiveWebViews)
            self.maxConcurrentActiveWebViews = max(1, maxConcurrentActiveWebViews)
        }
    }

    public var regular: ProfileBudget
    public var privateProfile: ProfileBudget

    public init(regular: ProfileBudget, privateProfile: ProfileBudget) {
        self.regular = regular
        self.privateProfile = privateProfile
    }
}

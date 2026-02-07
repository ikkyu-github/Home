import SafariLikeContracts

public typealias PluginCapability = SafariLikeContracts.PluginCapability

public extension PluginCapability {
    /// Whether this capability implies the plugin must be applied to / bound to a `WKWebView`
    /// (e.g. content rule lists or user scripts that live in `WKUserContentController`).
    var isWebViewBound: Bool {
        switch self {
        case .contentBlocking, .contentScripts, .contentInjection:
            return true
        case .navigationRead, .navigationIntercept, .navigationObserver, .analytics, .uiAugmentation, .experimental, .websitePreferences, .toolbarCommands,
             .historyRead, .bookmarksRead, .tabObservation:
            return false
        @unknown default:
            return false
        }
    }
}


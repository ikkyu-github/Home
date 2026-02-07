/// Marker protocol for plugins that are explicitly allowed to receive WebView/tab lifecycle hooks.
///
/// The host uses conformance as an explicit opt-in signal before invoking
/// WebView-bound hooks such as `webViewWillDetach(tabID:)`.
@MainActor
public protocol WebViewLifecyclePlugin: BrowserPlugin {}

import Foundation

/// Debug signals for WebView lifecycle instrumentation.
///
/// Notes:
/// - The notification names are defined in all builds for API stability.
/// - Events are posted only in DEBUG builds (see call sites).
public enum WebViewLifecycleDebugNotifications {
    public static let webViewCreated = Notification.Name("SafariLike.webviewLifecycle.webViewCreated")
    public static let webViewReused = Notification.Name("SafariLike.webviewLifecycle.webViewReused")

    public enum UserInfoKey {
        public static let tabID = "tabID" // UUID string
        public static let windowID = "windowID"
        public static let paneID = "paneID"
        public static let role = "role"
    }
}

import Foundation
import UIKit
import WebKit
import SafariLikeCoreKit
public enum WebViewRealityProbe {
    /// Capture a read-only snapshot of the WKWebView's current attachment/visibility reality.
    ///
    /// Performance:
    /// - Intentionally cheap: only reads properties.
    /// - Does not call `layoutIfNeeded()` or trigger any side effects.
    @inlinable
    public static func snapshot(tabID: UUID, webView: WKWebView) -> WebViewRealitySnapshot {
        let hasSuperview = (webView.superview != nil)
        let hasWindow = (webView.window != nil)
        let frame = webView.frame
        let isVisible = (webView.isHidden == false) && (webView.alpha > 0.01)
        let webViewObjectID = WebViewRealitySnapshot.objectID(for: webView)
        return WebViewRealitySnapshot(
            tabID: tabID,
            webViewObjectID: webViewObjectID,
            hasSuperview: hasSuperview,
            hasWindow: hasWindow,
            frame: frame,
            isVisible: isVisible,
            timestamp: Date()
        )
    }
}

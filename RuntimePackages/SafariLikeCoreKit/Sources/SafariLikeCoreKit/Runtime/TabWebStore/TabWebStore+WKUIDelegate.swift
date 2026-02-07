import WebKit
import BrowserCore
import Foundation

extension TabWebStore: WKUIDelegate {
	@available(iOS 15.0, *)
	public func webView(
		_ webView: WKWebView,
		requestMediaCapturePermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		type: WKMediaCaptureType,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		navigationController.webView(
			webView,
			requestMediaCapturePermissionFor: origin,
			initiatedByFrame: frame,
			type: type,
			decisionHandler: decisionHandler
		)
	}

	@available(iOS 15.0, *)
	public func webView(
		_ webView: WKWebView,
		requestGeolocationPermissionFor origin: WKSecurityOrigin,
		initiatedByFrame frame: WKFrameInfo,
		decisionHandler: @escaping (WKPermissionDecision) -> Void
	) {
		navigationController.webView(
			webView,
			requestGeolocationPermissionFor: origin,
			initiatedByFrame: frame,
			decisionHandler: decisionHandler
		)
	}
}

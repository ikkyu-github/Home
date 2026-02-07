import Foundation
import WebKit

extension TabWebStore: WKDownloadDelegate {
    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        if #available(iOS 14.5, macOS 11.3, *) {
			navigationController.webView(webView, navigationAction: navigationAction, didBecome: download)
		}
    }

    /// Threading: Called by WebKit on the main actor.
    public func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        WebViewPool.assertWebViewAllocatedByPool(webView)
        if #available(iOS 14.5, macOS 11.3, *) {
			navigationController.webView(webView, navigationResponse: navigationResponse, didBecome: download)
		}
    }

    /// Threading: Called by WebKit on the main actor.
    public func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        if #available(iOS 14.5, macOS 11.3, *) {
            navigationController.download(download, decideDestinationUsing: response, suggestedFilename: suggestedFilename, completionHandler: completionHandler)
        } else {
            let destinationURL = onDownloadDecideDestination?(download, response, suggestedFilename)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(suggestedFilename)
            completionHandler(destinationURL)
        }
    }

    /// Threading: Called by WebKit on the main actor.
    public func download(_ download: WKDownload, didReceive response: URLResponse) {
        // Download started
    }

    /// Threading: Called by WebKit on the main actor.
    public func download(_ download: WKDownload, didReceive data: Data) {
        // Progress update if needed
    }

    /// Threading: Called by WebKit on the main actor.
    public func downloadDidFinish(_ download: WKDownload) {
        if #available(iOS 14.5, macOS 11.3, *) {
			navigationController.downloadDidFinish(download)
		}
    }

    /// Threading: Called by WebKit on the main actor.
    public func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        if #available(iOS 14.5, macOS 11.3, *) {
            navigationController.download(download, didFailWithError: error, resumeData: resumeData)
        } else {
            onDownloadDidFail?(error)
        }
    }
}

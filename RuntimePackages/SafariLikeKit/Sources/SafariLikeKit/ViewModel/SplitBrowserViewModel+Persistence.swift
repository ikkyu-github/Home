import Foundation
import SafariLikeCoreKit

@MainActor
extension SplitBrowserViewModel {
    // MARK: Lifecycle
    /// Release heavy WKWebView runtime state for both modes.
    func invalidate() {
        chrome.unbind()
        downloadStore.purgePrivateDownloadsForScene()
        // Cancel any tasks/subscriptions if present (add here if needed)
        Task { @MainActor in
            await tabManager.shutdown()
            await normalTabRegistry.removeAll()
            await privateTabRegistry.removeAll()

            // Private mode parity: clear all private session state on shutdown.
            privateSessionStore.resetToSingleNewTab()
        }
    }
}

import Foundation
import WebKit
import os

extension TabWebStore {
    internal func configureWebViewAfterInit(defaultHomeURLString: String) {
		navigationController.configureWebViewAfterInit(defaultHomeURLString: defaultHomeURLString)
    }

    /// Prepare an existing WKWebView instance for reuse with the same
    /// TabWebStore.
    ///
    /// This is a low-level lifecycle hook intended for scenarios where a
    /// WebView is recycled for the same logical tab (for example after
    /// process recovery or future pooling strategies).
    ///
    /// Current TabRegistry semantics prefer creating a fresh TabWebStore
    /// per tab and calling `invalidate()` on release, so this method is
    /// not used in production flows yet. It exists to make reuse semantics
    /// explicit and safe without changing external APIs.
    ///
    /// Contract:
    /// - Must be called on the main actor.
    /// - Must only be used while `isInvalidated == false` and the
    ///   underlying `webViewHandle` is still alive.
    /// - Delegates all internal task cancellation and state reset to
    ///   `resetForReuseInternal(defaultHomeURLString:)` to preserve
    ///   encapsulation.
    /// - Leaves WebView delegate teardown / reconfiguration to this
    ///   extension.
    internal func resetForReuse(defaultHomeURLString: String) {
		navigationController.resetForReuse(defaultHomeURLString: defaultHomeURLString)
    }

    // MARK: - Load helpers
    internal func performLoadResolvedURL(_ urlString: String) {
		navigationController.performLoadResolvedURL(urlString)
    }

    internal func attemptPerformPendingLoad(reason: String) {
		navigationController.attemptPerformPendingLoad(reason: reason)
    }

    internal func invalidateWebViewCore() {
		navigationController.invalidateWebViewCore()
    }
}

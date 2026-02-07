import Foundation

extension TabWebStore {
    /// Deterministically apply the current content blocking configuration to this webView.
    func applyContentBlocking() {
		contentBlockingController.applyContentBlocking()
    }

    /// Explicit hook for callers to re-apply content blocking after settings change.
    func refreshContentBlockingRules() {
		contentBlockingController.refreshContentBlockingRules()
    }
}

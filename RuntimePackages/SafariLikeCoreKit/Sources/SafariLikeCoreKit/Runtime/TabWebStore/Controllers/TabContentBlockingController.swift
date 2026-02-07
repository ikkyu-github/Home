import Foundation

@MainActor
public protocol TabContentBlockingControlling: AnyObject {
	func applyContentBlocking()
	func refreshContentBlockingRules()
}

@MainActor
public final class TabContentBlockingController: NSObject, TabContentBlockingControlling {
	private unowned let store: TabWebStore

	public init(store: TabWebStore) {
		self.store = store
		super.init()
	}

	/// Deterministically apply the current content blocking configuration to this webView.
	public func applyContentBlocking() {
		guard let manager = store.contentBlockerManager,
			  manager.isEnabled,
			  manager.isReady,
			  let handle = store.webViewHandle,
			  handle.isAlive
		else { return }
		// CoreKit currently exposes only deterministic state for content blocking.
		// Actual rule compilation/application is provided by higher layers.
		_ = manager
	}

	/// Explicit hook for callers to re-apply content blocking after settings change.
	public func refreshContentBlockingRules() {
		applyContentBlocking()
	}
}

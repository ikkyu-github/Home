import Foundation
import os

extension TabWebStore {
    /// Threading: Call on the main actor.
    public func load(_ urlString: String, force: Bool) {
		navigationController.load(urlString, force: force)
    }

    /// Threading: Call on the main actor.
    public func setBypassSmartSplitOnce() { navigationController.setBypassSmartSplitOnce() }

    /// Threading: Call on the main actor.
    public func loadSearch(query: String) {
		navigationController.loadSearch(query: query)
    }
}

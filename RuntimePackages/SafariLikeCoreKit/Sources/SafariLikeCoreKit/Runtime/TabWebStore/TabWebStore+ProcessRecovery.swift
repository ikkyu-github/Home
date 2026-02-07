import Foundation

extension TabWebStore {
	/// Handle content process termination with bounded, exponential backoff reload attempts.
	internal func scheduleProcessRecoverIfNeeded() {
		processRecoveryController.scheduleProcessRecoverIfNeeded()
	}
}

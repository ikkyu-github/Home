import Foundation

@MainActor
public protocol TabProcessRecoveryControlling: AnyObject {
	func scheduleProcessRecoverIfNeeded()
}

@MainActor
public final class TabProcessRecoveryController: NSObject, TabProcessRecoveryControlling {
	private unowned let store: TabWebStore

	public init(store: TabWebStore) {
		self.store = store
		super.init()
	}

	/// Handle content process termination with bounded, exponential backoff reload attempts.
	public func scheduleProcessRecoverIfNeeded() {
		guard !store.isInvalidated, !Task.isCancelled else { return }
		guard let handle = store.webViewHandle, handle.isAlive else { return }
		guard isAppActive() else { return }
		guard handle.url != nil else { return }

		let now = CFAbsoluteTimeGetCurrent()
		store.lastProcessTerminateAt = now

		if (now - store.lastProcessRecoverAt) < 2.0 {
			store.processRecoverAttempts += 1
		} else {
			store.processRecoverAttempts = max(0, store.processRecoverAttempts - 1)
		}

		guard store.processRecoverAttempts <= 6 else { return }

		let baseDelay: Double = 0.20
		let delay = min(10.0, baseDelay * pow(2.0, Double(store.processRecoverAttempts)))
		store.lastProcessRecoverDelayForTesting = delay

		store.pendingProcessRecoverTask?.cancel()
		store.pendingProcessRecoverTask = store.runTask { @MainActor [weak store] in
			guard let store, !store.isInvalidated, !Task.isCancelled else { return }
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			guard !Task.isCancelled, !store.isInvalidated else { return }
			let isActive: Bool = {
				if let isAppActiveClosure = store.isAppActiveClosure {
					return isAppActiveClosure()
				}
				return true
			}()
			guard isActive else { return }
			store.lastProcessRecoverAt = CFAbsoluteTimeGetCurrent()
			guard let handle = store.webViewHandle, handle.isAlive else { return }
			handle.reload()
		}
	}

	private func isAppActive() -> Bool {
		if let isAppActiveClosure = store.isAppActiveClosure {
			return isAppActiveClosure()
		}
		return true
	}
}

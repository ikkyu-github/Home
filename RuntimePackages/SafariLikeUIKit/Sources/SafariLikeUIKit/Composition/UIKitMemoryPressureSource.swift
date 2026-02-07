import SafariLikeCoreKit
import UIKit

/// UIKit implementation of SafariLikeCoreKit's `EngineMemoryPressureSource`.
///
/// Layering:
/// - CoreKit defines the protocol.
/// - SafariLikeUIKit (UI glue) implements it using UIKit notifications.
@MainActor
public final class UIKitMemoryPressureSource: EngineMemoryPressureSource {
	private let notificationCenter: NotificationCenter
	private var handler: (@Sendable (EngineController.MemoryPressureLevel) -> Void)?
	private var observer: NSObjectProtocol?

	public init(notificationCenter: NotificationCenter = .default) {
		self.notificationCenter = notificationCenter
		self.observer = notificationCenter.addObserver(
			forName: UIApplication.didReceiveMemoryWarningNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.handler?(.warning)
			}
		}
	}

	deinit {
		// NOTE: Observer removal is handled automatically for block-based observers
		// when NotificationCenter is deallocated; but NotificationCenter is global.
		// Remove explicitly to avoid retaining cycles/leaks.
		if let observer {
			notificationCenter.removeObserver(observer)
		}
	}

	public func setHandler(_ handler: (@Sendable (EngineController.MemoryPressureLevel) -> Void)?) {
		self.handler = handler
	}
}

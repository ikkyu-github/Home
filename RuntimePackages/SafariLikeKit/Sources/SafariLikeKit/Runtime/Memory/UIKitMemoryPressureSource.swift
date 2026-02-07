import Foundation
import SafariLikeCoreKit
import UIKit
/// UIKit implementation of SafariLikeCoreKit's `EngineMemoryPressureSource`.
///
/// Lives in SafariLikeKit so the app target doesn't need to import SafariLikeUIKit.
@MainActor
public final class UIKitMemoryPressureSource: EngineMemoryPressureSource {
    private var observer: NSObjectProtocol?
    private var handler: (@Sendable (EngineController.MemoryPressureLevel) -> Void)?
    public init() {}
    public func setHandler(_ handler: (@Sendable (EngineController.MemoryPressureLevel) -> Void)?) {
        self.handler = handler
        if let observer {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
        guard handler != nil else { return }
        let capturedHandler = handler
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            capturedHandler?(.critical)
        }
    }
    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

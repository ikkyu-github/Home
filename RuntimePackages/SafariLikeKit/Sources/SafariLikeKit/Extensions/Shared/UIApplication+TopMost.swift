import UIKit
import SafariLikeCoreKit
extension UIApplication {
    @MainActor
    func topMostViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC: UIViewController? = {
            if let base { return base }
            if let scene = connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
               let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window.rootViewController
            }
            return nil
        }()
        guard let vc = baseVC else { return nil }
        if let nav = vc as? UINavigationController {
            return topMostViewController(base: nav.visibleViewController)
        }
        if let tab = vc as? UITabBarController {
            return topMostViewController(base: tab.selectedViewController)
        }
        if let presented = vc.presentedViewController {
            return topMostViewController(base: presented)
        }
        return vc
    }
}

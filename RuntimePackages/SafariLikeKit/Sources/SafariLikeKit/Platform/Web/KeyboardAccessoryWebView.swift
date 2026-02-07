import UIKit
import WebKit
import SafariLikeCoreKit
@MainActor
final class KeyboardAccessoryWebView: WKWebView {
    /// The view presented above the keyboard when the web view is the first responder.
    /// This is typically a hosted SwiftUI SafariHeaderView.
    var accessoryView: UIView?
    /// Gate for showing the accessory view.
    ///
    /// IMPORTANT:
    /// - When the user is typing inside web content (HTML input), the web view becomes first responder.
    ///   In that case we must NOT show the Safari-like URL bar accessory.
    /// - When the user is editing the URL field, we intentionally make the web view first responder
    ///   (to attach the accessory). In that case, this should be `true`.
    var isAccessoryEnabled: Bool = false
    /// Callback to notify SwiftUI / ViewModel
    var onWebViewBecameFirstResponder: (() -> Void)?
    /// Optional: notify when web view resigns first responder (blur)
    var onWebViewResignedFirstResponder: (() -> Void)?
    override var inputAccessoryView: UIView? {
        isAccessoryEnabled ? accessoryView : nil
    }
    override var canBecomeFirstResponder: Bool {
        true
    }
    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        if didBecome {
            // Web content is now active (NOT address bar)
            onWebViewBecameFirstResponder?()
        }
        return didBecome
    }
    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign {
            onWebViewResignedFirstResponder?()
        }
        return didResign
    }
}

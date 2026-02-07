import Foundation
import WebKit
import SafariLikeCoreKit
@MainActor
extension WKWebView {
    func evaluateJavaScriptAsync(_ javaScriptString: String) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            evaluateJavaScript(javaScriptString) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result as Any)
            }
        }
    }
    /// ⚠️ Deprecated: Disabling WKWebView's input accessory view via runtime method replacement is a
    /// fragile WebKit implementation detail and may break across iOS versions or cause undefined behavior.
    ///
    /// This project already uses `KeyboardAccessoryWebView` to *conditionally* show a custom accessory view
    /// (URL bar) only when appropriate.
    ///
    /// Keeping this API as a no-op preserves source compatibility without shipping a time bomb.
    @available(*, deprecated, message: "No-op. Use KeyboardAccessoryWebView.isAccessoryEnabled + accessoryView instead.")
    func disableInputAccessoryView() {
        // Intentionally left blank.
    }
}

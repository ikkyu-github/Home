import Foundation
import BrowserCore
import SafariLikeContracts

#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

/// CoreKit adapter for best-effort system Autofill capability checks.
///
/// Important:
/// - Does not request credentials.
/// - Does not log relying party identifiers or domains.
public final class AppleAutofillSystemChecker: AutofillSystemChecking {
    public init() {}

    public func checkAvailability() async -> AutofillAvailability {
        let now = Date()

        #if canImport(AuthenticationServices)
        // Best-effort: newer iOS versions support Passkeys in WebKit.
        // Avoid relying on private/unstable capability APIs.
        let supportsPasskeys: Bool = {
            if #available(iOS 16.0, *) { return true }
            return false
        }()

        // iOS does not provide a supported API to know if "Passwords" autofill is enabled.
        // We treat the platform as capable and rely on user settings at runtime.
        let supportsPasswords = true
        #else
        let supportsPasskeys = false
        let supportsPasswords = false
        #endif

        let isEnabled = (supportsPasskeys || supportsPasswords)

        return AutofillAvailability(
            isEnabled: isEnabled,
            supportsPasskeys: supportsPasskeys,
            supportsPasswords: supportsPasswords,
            lastCheckedAt: now
        )
    }
}

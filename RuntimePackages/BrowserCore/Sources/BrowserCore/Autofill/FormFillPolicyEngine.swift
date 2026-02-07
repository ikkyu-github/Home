import Foundation
import SafariLikeContracts

/// Computes deterministic Autofill/Passkeys policy for a site + profile.
///
/// Contract:
/// - Does not store or handle any credentials.
/// - Read-only: returns a value-type `FormFillPolicy` suitable for UI gating and runtime wiring.
public struct FormFillPolicyEngine {
    public struct GlobalDefaults {
        public var allowAutofill: @Sendable () -> Bool
        public var allowPasswordSaving: @Sendable () -> Bool

        public init(
            allowAutofill: @escaping @Sendable () -> Bool,
            allowPasswordSaving: @escaping @Sendable () -> Bool
        ) {
            self.allowAutofill = allowAutofill
            self.allowPasswordSaving = allowPasswordSaving
        }

        public static let permissive = GlobalDefaults(
            allowAutofill: { true },
            allowPasswordSaving: { true }
        )
    }

    private let defaults: GlobalDefaults
    private weak var websitePreferencesStore: (any WebsitePreferencesProviding)?

    public init(
        defaults: GlobalDefaults = .permissive,
        websitePreferencesStore: any WebsitePreferencesProviding
    ) {
        self.defaults = defaults
        self.websitePreferencesStore = websitePreferencesStore
    }

    /// Compute the effective policy for this site/profile.
    ///
    /// Notes:
    /// - Passkeys on the web typically require JavaScript (WebAuthn), so `allowPasskeys`
    ///   is gated by per-site JavaScript preference.
    /// - Private profile never allows password saving prompts.
    public func effectivePolicy(siteKey: SiteKey, profile: WebsiteDataProfile) -> FormFillPolicy {
        let prefs = websitePreferencesStore?.getPreferences(for: siteKey.storageKey)
            ?? WebsitePreferences.defaults(for: siteKey.storageKey)

        let globalAllowAutofill = defaults.allowAutofill()
        let siteAllowAutofill = prefs.autofillEnabled

        let allowAutofill = globalAllowAutofill && siteAllowAutofill
        let allowPasskeys = allowAutofill && prefs.javaScriptEnabled

        let allowPasswordSaving: Bool = {
            guard allowAutofill else { return false }
            guard profile == .regular else { return false }
            return defaults.allowPasswordSaving()
        }()

        return FormFillPolicy(
            allowAutofill: allowAutofill,
            allowPasskeys: allowPasskeys,
            allowPasswordSaving: allowPasswordSaving,
            profile: profile,
            siteKey: siteKey
        )
    }
}

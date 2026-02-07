import Foundation

// MARK: - Autofill / Passwords / Passkeys

/// Best-effort snapshot of whether system Autofill features are likely available.
///
/// Notes:
/// - This intentionally contains **no** per-site information and **no** sensitive details.
/// - Values are best-effort because iOS does not expose a full, supported API to read
///   all user-level Passwords/Autofill toggles.
public struct AutofillAvailability: Codable, Sendable, Hashable {
    public let isEnabled: Bool
    public let supportsPasskeys: Bool
    public let supportsPasswords: Bool
    public let lastCheckedAt: Date

    public init(
        isEnabled: Bool,
        supportsPasskeys: Bool,
        supportsPasswords: Bool,
        lastCheckedAt: Date
    ) {
        self.isEnabled = isEnabled
        self.supportsPasskeys = supportsPasskeys
        self.supportsPasswords = supportsPasswords
        self.lastCheckedAt = lastCheckedAt
    }
}

/// Deterministic, layer-safe policy used to gate Autofill-related UX and any helper instrumentation.
///
/// Important:
/// - This does **not** store or handle credentials.
/// - "Saving" is handled by the system; this flag only gates prompts/UX and helper behavior.
public struct FormFillPolicy: Codable, Sendable, Hashable {
    public let allowAutofill: Bool
    public let allowPasskeys: Bool
    public let allowPasswordSaving: Bool

    public let profile: WebsiteDataProfile
    public let siteKey: SiteKey

    public init(
        allowAutofill: Bool,
        allowPasskeys: Bool,
        allowPasswordSaving: Bool,
        profile: WebsiteDataProfile,
        siteKey: SiteKey
    ) {
        self.allowAutofill = allowAutofill
        self.allowPasskeys = allowPasskeys
        self.allowPasswordSaving = allowPasswordSaving
        self.profile = profile
        self.siteKey = siteKey
    }
}

/// Semantic deep links used by UI layers to provide help shortcuts.
///
/// Best-effort: some system settings pages are not publicly deep-linkable.
public struct SettingsDeepLink: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable, Hashable {
        case openPasswordsSettings
        case openAutofillSettings
        case openAssociatedDomainsHelp
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}

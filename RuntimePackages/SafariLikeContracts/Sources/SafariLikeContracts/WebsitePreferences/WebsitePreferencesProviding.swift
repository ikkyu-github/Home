import Foundation

/// Platform-independent interface for per-website preference management.
///
/// This is a cross-layer contract: storage implementations can live in a UI
/// host, while core/runtime can depend on it without importing UI modules.
public protocol WebsitePreferencesProviding: AnyObject {
    func getPreferences(for domain: String) -> WebsitePreferences
    func setPreferences(_ preferences: WebsitePreferences, for domain: String)
    func allPreferences() -> [WebsitePreferences]
    func clearPreferences(for domain: String)
    func clearAllPreferences()
}

public extension WebsitePreferencesProviding {
    func setPreferences(_ updates: [String: WebsitePreferences]) {
        for (domain, preferences) in updates {
            setPreferences(preferences, for: domain)
        }
    }

    func hasCustomPreferences(for domain: String) -> Bool {
        let current = getPreferences(for: domain)
        let defaults = WebsitePreferences.defaults(for: domain)
        return current != defaults
    }

    func customizedDomains() -> [String] {
        allPreferences()
            .filter { $0 != WebsitePreferences.defaults(for: $0.domain) }
            .map { $0.domain }
    }
}

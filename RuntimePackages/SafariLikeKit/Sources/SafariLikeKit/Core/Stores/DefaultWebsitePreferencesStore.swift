import Foundation
import SafariLikeContracts
import SafariLikeCoreKit
/// Core-only default implementation of WebsitePreferencesProviding.
///
/// This store lives in SafariLikeKit and depends only on BrowserCore.
/// It is used in cases where the UIKit-specific WebsitePreferencesStore
/// is not injected from SafariLikeUIKit. Apps using SafariLikeUIKit
/// should prefer that implementation instead.
@MainActor
final class DefaultWebsitePreferencesStore: WebsitePreferencesProviding {
    private var map: [String: WebsitePreferences] = [:]
    func getPreferences(for domain: String) -> WebsitePreferences {
        guard !domain.isEmpty else { return WebsitePreferences(domain: domain) }
        return map[domain] ?? WebsitePreferences.defaults(for: domain)
    }
    func setPreferences(_ preferences: WebsitePreferences, for domain: String) {
        guard !domain.isEmpty else { return }
        map[domain] = preferences
    }
    func allPreferences() -> [WebsitePreferences] {
        Array(map.values)
    }
    func clearPreferences(for domain: String) {
        guard !domain.isEmpty else { return }
        map.removeValue(forKey: domain)
    }
    func clearAllPreferences() {
        map.removeAll()
    }
}

import WebKit

/// WebKit-specific contract for applying per-site website preferences.
///
/// Note: This cannot live in SafariLikeContracts because Contracts must not import WebKit.
@MainActor
public protocol WebsitePreferencesApplying {
	func applyPreferences(to configuration: WKWebViewConfiguration, forHost host: String)
}

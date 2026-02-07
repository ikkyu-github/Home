import Foundation
import SafariLikeCoreKit
/// Read-only snapshot of browser settings that plugins may use to make
/// lightweight decisions.
///
/// This is intentionally minimal and safe: it does not expose any mutable
/// state, WebView objects, or app internals.
public struct BrowserSettingsSnapshot: Sendable, Equatable {
    public enum UserAgentMode: String, Sendable, Codable, CaseIterable {
        case mobile
        case desktop
    }
    /// Whether content blocking is enabled.
    public var isContentBlockingEnabled: Bool
    /// The current user agent mode.
    public var userAgentMode: UserAgentMode
    /// The browser search engine URL template used for omnibox searches.
    /// Example: "https://www.google.com/search?q=%@"
    public var searchEngineURLTemplate: String
    public init(
        isContentBlockingEnabled: Bool,
        userAgentMode: UserAgentMode,
        searchEngineURLTemplate: String
    ) {
        self.isContentBlockingEnabled = isContentBlockingEnabled
        self.userAgentMode = userAgentMode
        self.searchEngineURLTemplate = searchEngineURLTemplate
    }
}

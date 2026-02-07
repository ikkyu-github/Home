import Foundation

/// Centralized default URLs used across the Safari-like stack.
///
/// Single Source of Truth: defined in SafariLikeContracts so that BrowserCore/SafariLikeKit/
/// SafariLikeCoreKit can re-export without duplicating URL building logic.
public enum DefaultURLs {
    /// A universally safe fallback URL.
    /// `about:blank` should always parse, but we still provide a file URL fallback.
    public static let aboutBlank: URL = URL(string: "about:blank") ?? URL(fileURLWithPath: "/")

    public static let googleHomepage: URL = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        return components.url ?? aboutBlank
    }()

    public enum SearchEngine {
        /// https://www.google.com/search?q=
        public static let googleQuery: URL = {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: "")]
            return components.url ?? DefaultURLs.aboutBlank
        }()

        /// https://www.bing.com/search?q=
        public static let bingQuery: URL = {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.bing.com"
            components.path = "/search"
            components.queryItems = [URLQueryItem(name: "q", value: "")]
            return components.url ?? DefaultURLs.aboutBlank
        }()

        /// https://duckduckgo.com/?q=
        public static let duckDuckGoQuery: URL = {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "duckduckgo.com"
            components.path = "/"
            components.queryItems = [URLQueryItem(name: "q", value: "")]
            return components.url ?? DefaultURLs.aboutBlank
        }()
    }
}

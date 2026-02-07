import Foundation

/// Safari-like URL normalization for omnibox/favorites inputs.
///
/// Goals:
/// - Trim whitespace
/// - If input is a search keyword, convert to a concrete search URL
/// - If input has no scheme, prepend `https://`
/// - Avoid producing `about:blank` for user inputs
public enum URLStringNormalizer {
    public enum Kind: Sendable, Equatable {
        case url
        case search
    }

    public struct Result: Sendable, Equatable {
        public let urlString: String
        public let kind: Kind

        public init(urlString: String, kind: Kind) {
            self.urlString = urlString
            self.kind = kind
        }
    }

    /// Resolves a raw user/favorite input string into a concrete URL string.
    ///
    /// - Returns: `nil` when the input is empty or `about:blank`.
    public static func resolve(_ raw: String, searchEngineURL: URL) -> Result? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let lowered = trimmed.lowercased()
        if lowered == "about:blank" { return nil }

        // Any whitespace means search (Safari-like).
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            if let searchURLString = buildSearchURLString(query: trimmed, searchEngineURL: searchEngineURL) {
                return Result(urlString: searchURLString, kind: .search)
            }
            return nil
        }

        // Explicit scheme present (e.g. http:, https:, file:, about:, etc).
        if let schemeRange = lowered.range(of: #"^[a-z][a-z0-9+\-.]*:"#, options: .regularExpression) {
            // Ensure http/https have //.
            var candidate = trimmed
            if lowered.hasPrefix("http:") || lowered.hasPrefix("https:") {
                let afterColonIndex = candidate.index(candidate.startIndex, offsetBy: schemeRange.upperBound.utf16Offset(in: lowered))
                if candidate[afterColonIndex...].hasPrefix("//") == false {
                    candidate.insert(contentsOf: "//", at: afterColonIndex)
                }
            }

            if let url = URL(string: candidate), url.scheme != nil {
                return Result(urlString: url.absoluteString, kind: .url)
            }

            // If an explicit-scheme parse fails, fall back to search.
            if let searchURLString = buildSearchURLString(query: trimmed, searchEngineURL: searchEngineURL) {
                return Result(urlString: searchURLString, kind: .search)
            }
            return nil
        }

        // No explicit scheme.
        if looksLikeURLCandidate(trimmed) {
            var candidate = trimmed
            if candidate.hasPrefix("//") {
                candidate = "https:" + candidate
            } else {
                candidate = "https://" + candidate
            }

            if let url = URL(string: candidate) {
                return Result(urlString: url.absoluteString, kind: .url)
            }
        }

        // Fallback: search.
        if let searchURLString = buildSearchURLString(query: trimmed, searchEngineURL: searchEngineURL) {
            return Result(urlString: searchURLString, kind: .search)
        }

        return nil
    }

    private static func looksLikeURLCandidate(_ s: String) -> Bool {
        // Common URL indicators.
        if s.contains(".") { return true }
        if s.contains("/") { return true }
        if s.contains(":") { return true }

        let lowered = s.lowercased()
        if lowered == "localhost" { return true }
        if lowered.hasPrefix("localhost:") { return true }

        // IPv4.
        if lowered.range(of: #"^\d{1,3}(?:\.\d{1,3}){3}(?::\d+)?$"#, options: .regularExpression) != nil {
            return true
        }

        // Bracketed IPv6-ish.
        if lowered.hasPrefix("[") && lowered.contains("]") { return true }

        return false
    }

    private static func buildSearchURLString(query: String, searchEngineURL: URL) -> String? {
        guard var components = URLComponents(url: searchEngineURL, resolvingAgainstBaseURL: false) else { return nil }

        // Prefer queryItems when available (robust encoding).
        if components.queryItems != nil {
            var items = components.queryItems ?? []
            if let idx = items.firstIndex(where: { $0.name.lowercased() == "q" }) {
                items[idx] = URLQueryItem(name: items[idx].name, value: query)
            } else {
                items.append(URLQueryItem(name: "q", value: query))
            }
            components.queryItems = items
            return components.url?.absoluteString
        }

        // Fallback for templates that rely on an empty query string being present.
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let existing = components.percentEncodedQuery, existing.isEmpty == false {
            components.percentEncodedQuery = existing + encoded
        } else {
            components.percentEncodedQuery = encoded
        }
        return components.url?.absoluteString
    }
}

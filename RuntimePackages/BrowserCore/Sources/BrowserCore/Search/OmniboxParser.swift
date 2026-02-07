import Foundation
import SafariLikeContracts

/// Deterministic Safari-like omnibox parsing.
///
/// Rules (high-level):
/// - Trim whitespace/newlines
/// - Empty or `about:blank` => nil
/// - Any whitespace inside => search
/// - Explicit scheme => URL (with `http(s):` fixed to include `//`)
/// - No scheme + URL-ish heuristics => assume `https://`
/// - Otherwise => search
public enum OmniboxParser {
    public static func resolve(_ raw: String, searchEngineTemplateURL: URL) -> OmniboxResolvedInput? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }

        let lowered = trimmed.lowercased()
        if lowered == "about:blank" { return nil }

        // Any whitespace means search (Safari-like).
        if trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
            if let searchURLString = SearchURLBuilder.buildSearchURLString(query: trimmed, templateURL: searchEngineTemplateURL) {
                return OmniboxResolvedInput(original: trimmed, resolvedURLString: searchURLString, kind: .search)
            }
            return nil
        }

        // Explicit scheme present (e.g. http:, https:, file:, about:, etc).
        if let schemeRange = lowered.range(of: #"^[a-z][a-z0-9+\-.]*:"#, options: .regularExpression) {
            // Special-case: inputs like "localhost:8080" are host:port, not a custom scheme.
            // If the post-colon portion is only digits (optionally followed by a path),
            // treat it as a no-scheme URL candidate and let the https:// heuristic apply.
            let scheme = String(lowered[schemeRange].dropLast())
            let afterColonIndex = trimmed.index(trimmed.startIndex, offsetBy: schemeRange.upperBound.utf16Offset(in: lowered))
            let afterColon = String(trimmed[afterColonIndex...])

            let schemesThatMayOmitSlashes: Set<String> = [
                "http", "https",
                "about", "file", "data", "javascript",
                "mailto", "tel",
                "ftp", "ws", "wss"
            ]
            let isHostPortLike = afterColon.range(of: #"^\d+(?:/.*)?$"#, options: .regularExpression) != nil
            let shouldTreatAsScheme = afterColon.hasPrefix("//") || schemesThatMayOmitSlashes.contains(scheme) || isHostPortLike == false

            if shouldTreatAsScheme {
                var candidate = trimmed

                // Ensure http/https have //.
                if scheme == "http" || scheme == "https" {
                    if candidate[afterColonIndex...].hasPrefix("//") == false {
                        candidate.insert(contentsOf: "//", at: afterColonIndex)
                    }
                }

                if let url = URL(string: candidate), url.scheme != nil {
                    return OmniboxResolvedInput(original: trimmed, resolvedURLString: url.absoluteString, kind: .url)
                }

                // If an explicit-scheme parse fails, fall back to search.
                if let searchURLString = SearchURLBuilder.buildSearchURLString(query: trimmed, templateURL: searchEngineTemplateURL) {
                    return OmniboxResolvedInput(original: trimmed, resolvedURLString: searchURLString, kind: .search)
                }

                return nil
            }
            // Else: host:port-like input, fall through to no-scheme heuristics.
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
                return OmniboxResolvedInput(original: trimmed, resolvedURLString: url.absoluteString, kind: .url)
            }
        }

        // Fallback: search.
        if let searchURLString = SearchURLBuilder.buildSearchURLString(query: trimmed, templateURL: searchEngineTemplateURL) {
            return OmniboxResolvedInput(original: trimmed, resolvedURLString: searchURLString, kind: .search)
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
}

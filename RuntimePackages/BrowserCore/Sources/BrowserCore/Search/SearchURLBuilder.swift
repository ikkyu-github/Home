import Foundation

public enum SearchURLBuilder {
    /// Build a concrete search URL from a template URL.
    ///
    /// Template convention:
    /// - If the URL contains a query item named `q`, it will be replaced.
    /// - Otherwise, the query is appended to the percent-encoded query string.
    public static func buildSearchURLString(query: String, templateURL: URL) -> String? {
        guard var components = URLComponents(url: templateURL, resolvingAgainstBaseURL: false) else { return nil }

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

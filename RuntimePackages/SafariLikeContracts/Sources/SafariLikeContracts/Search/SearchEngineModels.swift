import Foundation

// MARK: - Search Engines

public struct SearchEngineID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value
    }
}

public struct SearchEngineDefinition: Codable, Hashable, Sendable, Identifiable {
    public let id: SearchEngineID
    public var displayName: String

    /// Template URL used for search.
    ///
    /// Convention: if the template contains a query item named "q" it will be replaced.
    /// Otherwise, the query will be appended to the percent-encoded query string.
    public var queryTemplateURL: URL

    public init(
        id: SearchEngineID,
        displayName: String,
        queryTemplateURL: URL
    ) {
        self.id = id
        self.displayName = displayName
        self.queryTemplateURL = queryTemplateURL
    }
}

public enum SearchProfile: String, Codable, Sendable, CaseIterable {
    case regular
    case `private`
}

public extension SearchEngineDefinition {
    static let google = SearchEngineDefinition(
        id: "google",
        displayName: "Google",
        queryTemplateURL: DefaultURLs.SearchEngine.googleQuery
    )

    static let bing = SearchEngineDefinition(
        id: "bing",
        displayName: "Bing",
        queryTemplateURL: DefaultURLs.SearchEngine.bingQuery
    )

    static let duckDuckGo = SearchEngineDefinition(
        id: "duckduckgo",
        displayName: "DuckDuckGo",
        queryTemplateURL: DefaultURLs.SearchEngine.duckDuckGoQuery
    )

    static let defaults: [SearchEngineDefinition] = [google, bing, duckDuckGo]
}

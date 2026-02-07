import Foundation

public struct NavigationEntry: Codable, Sendable, Equatable, Hashable {
    public var urlString: String
    public var title: String?

    public init(urlString: String, title: String? = nil) {
        self.urlString = urlString
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}

import Foundation
import SafariLikeCoreKit
public struct BrowserHistoryItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var urlString: String
    public var visitedAt: Date
    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        visitedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.visitedAt = visitedAt
    }
}

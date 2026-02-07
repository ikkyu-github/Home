import Foundation
import SafariLikeCoreKit
public struct BrowserBookmark: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var urlString: String
    public var createdAt: Date
    public var updatedAt: Date
    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

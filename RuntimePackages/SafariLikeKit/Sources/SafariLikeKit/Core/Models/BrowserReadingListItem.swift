import Foundation
import SafariLikeCoreKit
public struct BrowserReadingListItem: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var urlString: String
    public var addedAt: Date
    public var lastOpenedAt: Date?
    public var isRead: Bool
    public init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        addedAt: Date = Date(),
        lastOpenedAt: Date? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
        self.isRead = isRead
    }
}

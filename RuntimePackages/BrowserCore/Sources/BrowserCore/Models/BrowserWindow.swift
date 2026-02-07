import Foundation

public struct BrowserWindow: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var tabs: [BrowserTab]
    public var selectedTabID: UUID?

    public init(
        id: UUID = UUID(),
        tabs: [BrowserTab] = [],
        selectedTabID: UUID? = nil
    ) {
        self.id = id
        self.tabs = tabs
        self.selectedTabID = selectedTabID
    }
}

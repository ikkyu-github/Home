import Foundation

public struct BrowserSession: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var windows: [BrowserWindow]
    public var selectedWindowID: UUID?

    public init(
        id: UUID = UUID(),
        windows: [BrowserWindow] = [],
        selectedWindowID: UUID? = nil
    ) {
        self.id = id
        self.windows = windows
        self.selectedWindowID = selectedWindowID
    }
}

import Foundation

public struct TabRestoreState: Sendable, Equatable {
    public var currentURL: URL?
    public var lastKnownTitle: String?

    public init(currentURL: URL? = nil, lastKnownTitle: String? = nil) {
        self.currentURL = currentURL
        self.lastKnownTitle = lastKnownTitle
    }
}

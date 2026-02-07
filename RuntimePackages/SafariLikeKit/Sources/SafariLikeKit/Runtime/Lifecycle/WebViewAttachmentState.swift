import Foundation
import SafariLikeCoreKit
public enum WebViewAttachmentState: Sendable {
    case idle
    case attaching
    case ready
    case restoring(snapshot: Data?)
    case timedOut
    case failed(reason: String?)
}
public struct WebViewAttachmentStatus: Sendable {
    public let tabID: UUID
    public let state: WebViewAttachmentState
    public let updatedAt: Date
    public init(tabID: UUID, state: WebViewAttachmentState, updatedAt: Date) {
        self.tabID = tabID
        self.state = state
        self.updatedAt = updatedAt
    }
}

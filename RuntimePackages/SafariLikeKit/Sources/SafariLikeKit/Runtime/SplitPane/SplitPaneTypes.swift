import Foundation
import SafariLikeCoreKit

public typealias PaneID = SafariLikeCoreKit.PaneID
public enum SplitMode: String, Codable, Sendable {
    case single
    case split
}
public struct PaneState: Codable, Sendable, Equatable {
    public var paneID: PaneID
    public var activeTabID: UUID?
    public var visible: Bool
    public var widthFraction: Double
    public var isPinned: Bool
    public init(
        paneID: PaneID,
        activeTabID: UUID? = nil,
        visible: Bool,
        widthFraction: Double,
        isPinned: Bool
    ) {
        self.paneID = paneID
        self.activeTabID = activeTabID
        self.visible = visible
        self.widthFraction = widthFraction
        self.isPinned = isPinned
    }
}


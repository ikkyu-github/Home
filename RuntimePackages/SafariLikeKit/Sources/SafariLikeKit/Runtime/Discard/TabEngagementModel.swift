import Foundation
import SafariLikeCoreKit
public struct TabEngagementModel: Sendable, Equatable {
    public let tabID: UUID
    public var lastVisibleAt: Date?
    public var lastInteractionAt: Date?
    public var isPlayingMedia: Bool
    public var hasPendingFormEdits: Bool
    public var estimatedMemoryCost: Int
    public var isPinned: Bool
    public var isPrivate: Bool
    public var isInActivePane: Bool
    public var backForwardDepth: Int
    public init(
        tabID: UUID,
        lastVisibleAt: Date? = nil,
        lastInteractionAt: Date? = nil,
        isPlayingMedia: Bool = false,
        hasPendingFormEdits: Bool = false,
        estimatedMemoryCost: Int = 0,
        isPinned: Bool = false,
        isPrivate: Bool = false,
        isInActivePane: Bool = false,
        backForwardDepth: Int = 0
    ) {
        self.tabID = tabID
        self.lastVisibleAt = lastVisibleAt
        self.lastInteractionAt = lastInteractionAt
        self.isPlayingMedia = isPlayingMedia
        self.hasPendingFormEdits = hasPendingFormEdits
        self.estimatedMemoryCost = estimatedMemoryCost
        self.isPinned = isPinned
        self.isPrivate = isPrivate
        self.isInActivePane = isInActivePane
        self.backForwardDepth = backForwardDepth
    }
}

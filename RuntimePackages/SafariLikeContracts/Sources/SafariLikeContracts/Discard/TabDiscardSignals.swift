import Foundation

public enum SiteCategory: String, Codable, Sendable {
    case video
    case doc
    case social
    case unknown
}

public enum DiscardDecision: String, Codable, Sendable {
    case keep
    case suspend
    case discard
}

public struct TabDiscardSignals: Codable, Sendable, Hashable {
    public var tabID: UUID

    public var lastInteractionTime: Date
    public var isPinned: Bool
    public var isPlayingMedia: Bool
    public var isEditingForm: Bool

    public var memoryCostEstimate: Int
    public var siteCategory: SiteCategory
    public var navigationDepth: Int
    public var isForegroundRecently: Bool

    public var isActive: Bool

    public var lastCommittedURL: URL?

    public init(
        tabID: UUID,
        lastInteractionTime: Date,
        isPinned: Bool,
        isPlayingMedia: Bool,
        isEditingForm: Bool,
        memoryCostEstimate: Int,
        siteCategory: SiteCategory,
        navigationDepth: Int,
        isForegroundRecently: Bool,
        isActive: Bool,
        lastCommittedURL: URL?
    ) {
        self.tabID = tabID
        self.lastInteractionTime = lastInteractionTime
        self.isPinned = isPinned
        self.isPlayingMedia = isPlayingMedia
        self.isEditingForm = isEditingForm
        self.memoryCostEstimate = memoryCostEstimate
        self.siteCategory = siteCategory
        self.navigationDepth = navigationDepth
        self.isForegroundRecently = isForegroundRecently
        self.isActive = isActive
        self.lastCommittedURL = lastCommittedURL
    }
}

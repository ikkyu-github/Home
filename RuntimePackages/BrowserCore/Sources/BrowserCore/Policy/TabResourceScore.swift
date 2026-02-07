import Foundation

/// Deterministic scoring for choosing which tabs to discard first.
public enum TabResourceScore {

    public struct Input: Sendable, Equatable {
        public var tabID: UUID
        public var lastActiveAt: Date
        public var isPinned: Bool
        public var isUserLocked: Bool
        public var hasUnsavedForm: Bool
        public var isPlayingMedia: Bool
        public var memoryCostEstimate: Int
        public var sitePolicyBias: Double

        public init(
            tabID: UUID,
            lastActiveAt: Date,
            isPinned: Bool,
            isUserLocked: Bool,
            hasUnsavedForm: Bool,
            isPlayingMedia: Bool,
            memoryCostEstimate: Int,
            sitePolicyBias: Double = 0
        ) {
            self.tabID = tabID
            self.lastActiveAt = lastActiveAt
            self.isPinned = isPinned
            self.isUserLocked = isUserLocked
            self.hasUnsavedForm = hasUnsavedForm
            self.isPlayingMedia = isPlayingMedia
            self.memoryCostEstimate = memoryCostEstimate
            self.sitePolicyBias = sitePolicyBias
        }
    }

    /// Returns a score where higher means "discard earlier".
    public static func score(
        _ input: Input,
        now: Date,
        config: TabDiscardConfig
    ) -> Double {
        let inactiveSeconds = max(0, now.timeIntervalSince(input.lastActiveAt))

        var s: Double = 0
        s += inactiveSeconds * config.weightRecencySeconds
        s += Double(max(0, input.memoryCostEstimate)) * config.weightMemoryCost
        s += input.sitePolicyBias

        if input.isPinned || input.isUserLocked {
            s -= config.penaltyPinnedOrLocked
        }
        if input.hasUnsavedForm {
            s -= config.penaltyUnsavedForm
        }
        if input.isPlayingMedia {
            s -= config.penaltyPlayingMedia
        }

        return s
    }
}

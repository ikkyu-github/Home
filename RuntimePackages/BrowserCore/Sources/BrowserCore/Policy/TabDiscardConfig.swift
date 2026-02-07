import Foundation

/// Central, immutable configuration for tab discard behavior.
///
/// Requirement: all thresholds live here (single source of truth).
public struct TabDiscardConfig: Sendable, Equatable {

    // MARK: - Triggers

    /// If the app stayed in background longer than this, allow aggressive discard on return.
    public var backgroundLongThreshold: TimeInterval

    /// If a tab was inactive longer than this, it becomes eligible for deeper discard.
    public var tabInactiveLongThreshold: TimeInterval

    /// When the total tab count exceeds this, start discarding oldest tabs (non-visible).
    public var highTabCountThreshold: Int

    /// Upper bound on how many tabs to process per policy application.
    public var maxActionsPerApply: Int

    // MARK: - Scoring Weights

    public var weightRecencySeconds: Double
    public var weightMemoryCost: Double
    public var penaltyPinnedOrLocked: Double
    public var penaltyUnsavedForm: Double
    public var penaltyPlayingMedia: Double

    // MARK: - Level Mapping

    /// Minimum staleness required for allowing level 3 (discardKeepToken).
    public var level3MinInactive: TimeInterval

    /// Minimum memory cost required for allowing level 3 under pressure.
    public var level3MinMemoryCost: Int

    /// Periodic sweep interval used by higher layers.
    public var sweepInterval: TimeInterval

    public init(
        backgroundLongThreshold: TimeInterval,
        tabInactiveLongThreshold: TimeInterval,
        highTabCountThreshold: Int,
        maxActionsPerApply: Int,
        weightRecencySeconds: Double,
        weightMemoryCost: Double,
        penaltyPinnedOrLocked: Double,
        penaltyUnsavedForm: Double,
        penaltyPlayingMedia: Double,
        level3MinInactive: TimeInterval,
        level3MinMemoryCost: Int,
        sweepInterval: TimeInterval
    ) {
        self.backgroundLongThreshold = backgroundLongThreshold
        self.tabInactiveLongThreshold = tabInactiveLongThreshold
        self.highTabCountThreshold = highTabCountThreshold
        self.maxActionsPerApply = maxActionsPerApply
        self.weightRecencySeconds = weightRecencySeconds
        self.weightMemoryCost = weightMemoryCost
        self.penaltyPinnedOrLocked = penaltyPinnedOrLocked
        self.penaltyUnsavedForm = penaltyUnsavedForm
        self.penaltyPlayingMedia = penaltyPlayingMedia
        self.level3MinInactive = level3MinInactive
        self.level3MinMemoryCost = level3MinMemoryCost
        self.sweepInterval = sweepInterval
    }

    public static let `default` = TabDiscardConfig(
        backgroundLongThreshold: 5 * 60,
        tabInactiveLongThreshold: 10 * 60,
        highTabCountThreshold: 25,
        maxActionsPerApply: 4,
        weightRecencySeconds: 1.0 / 60.0,
        weightMemoryCost: 2.2,
        penaltyPinnedOrLocked: 10_000,
        penaltyUnsavedForm: 2_000,
        penaltyPlayingMedia: 2_000,
        level3MinInactive: 30 * 60,
        level3MinMemoryCost: 80,
        sweepInterval: 60
    )
}

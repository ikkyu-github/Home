import Foundation

/// Pure, deterministic discard policy.
///
/// Contract:
/// - BrowserCore owns rules.
/// - Higher layers execute the returned actions.
public struct TabDiscardPolicy: Sendable {

    public struct TabDescriptor: Sendable, Equatable {
        public var tabID: UUID
        public var lastActiveAt: Date
        public var isVisible: Bool
        public var isPinned: Bool
        public var isUserLocked: Bool
        public var hasUnsavedForm: Bool
        public var isPlayingMedia: Bool
        public var memoryCostEstimate: Int
        public var currentLevel: TabDiscardLevel

        public init(
            tabID: UUID,
            lastActiveAt: Date,
            isVisible: Bool,
            isPinned: Bool,
            isUserLocked: Bool,
            hasUnsavedForm: Bool,
            isPlayingMedia: Bool,
            memoryCostEstimate: Int,
            currentLevel: TabDiscardLevel
        ) {
            self.tabID = tabID
            self.lastActiveAt = lastActiveAt
            self.isVisible = isVisible
            self.isPinned = isPinned
            self.isUserLocked = isUserLocked
            self.hasUnsavedForm = hasUnsavedForm
            self.isPlayingMedia = isPlayingMedia
            self.memoryCostEstimate = memoryCostEstimate
            self.currentLevel = currentLevel
        }
    }

    public struct Input: Sendable, Equatable {
        public var trigger: TabDiscardTrigger
        public var now: Date
        public var tabs: [TabDescriptor]

        public init(trigger: TabDiscardTrigger, now: Date, tabs: [TabDescriptor]) {
            self.trigger = trigger
            self.now = now
            self.tabs = tabs
        }
    }

    public struct Decision: Sendable, Equatable {
        /// Target level per tab. Only includes tabs that need a change.
        public var targetLevelByTabID: [UUID: TabDiscardLevel]

        /// Deterministic order for applying actions.
        public var orderedTabIDs: [UUID]

        public init(targetLevelByTabID: [UUID: TabDiscardLevel], orderedTabIDs: [UUID]) {
            self.targetLevelByTabID = targetLevelByTabID
            self.orderedTabIDs = orderedTabIDs
        }
    }

    public let config: TabDiscardConfig

    public init(config: TabDiscardConfig = .default) {
        self.config = config
    }

    public func decide(_ input: Input) -> Decision {
        let now = input.now

        // Always protect visible tabs at level 0 (keep attached).
        let visible = Set(input.tabs.compactMap { $0.isVisible ? $0.tabID : nil })

        // Build candidates: non-visible and not pinned/locked.
        var candidates: [(id: UUID, score: Double, descriptor: TabDescriptor)] = []
        candidates.reserveCapacity(input.tabs.count)

        for t in input.tabs {
            if visible.contains(t.tabID) { continue }
            if t.isPinned || t.isUserLocked { continue }

            let s = TabResourceScore.score(
                .init(
                    tabID: t.tabID,
                    lastActiveAt: t.lastActiveAt,
                    isPinned: t.isPinned,
                    isUserLocked: t.isUserLocked,
                    hasUnsavedForm: t.hasUnsavedForm,
                    isPlayingMedia: t.isPlayingMedia,
                    memoryCostEstimate: t.memoryCostEstimate
                ),
                now: now,
                config: config
            )
            candidates.append((t.tabID, s, t))
        }

        candidates.sort {
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.id.uuidString < $1.id.uuidString
        }

        let actionCap = max(0, config.maxActionsPerApply)
        var decided: [UUID: TabDiscardLevel] = [:]
        decided.reserveCapacity(min(actionCap, candidates.count))
        var ordered: [UUID] = []
        ordered.reserveCapacity(min(actionCap, candidates.count))

        func inactiveFor(_ t: TabDescriptor) -> TimeInterval {
            max(0, now.timeIntervalSince(t.lastActiveAt))
        }

        for c in candidates {
            if decided.count >= actionCap { break }

            let t = c.descriptor
            let age = inactiveFor(t)

            // Avoid aggressive discard for tabs with sensitive activity.
            if t.hasUnsavedForm || t.isPlayingMedia {
                continue
            }

            let target: TabDiscardLevel? = {
                switch input.trigger {
                case .memoryWarning(let level):
                    switch level {
                    case .critical:
                        if age >= config.level3MinInactive, t.memoryCostEstimate >= config.level3MinMemoryCost {
                            return .discardKeepToken
                        }
                        return .freezeCold
                    case .warning:
                        return .detachKeepSnapshot
                    }

                case .webViewOversubscribed:
                    return .detachKeepSnapshot

                case .thermalState:
                    if age >= config.level3MinInactive, t.memoryCostEstimate >= config.level3MinMemoryCost {
                        return .discardKeepToken
                    }
                    return .freezeCold

                case .appBackgroundedLong:
                    if age >= config.level3MinInactive {
                        return .discardKeepToken
                    }
                    return .freezeCold

                case .tabInactiveSweep:
                    if age < config.tabInactiveLongThreshold {
                        return nil
                    }
                    if age >= config.level3MinInactive {
                        return .discardKeepToken
                    }
                    return .freezeCold

                case .tabCountHigh(let count):
                    guard count >= config.highTabCountThreshold else { return nil }
                    if age >= config.level3MinInactive {
                        return .discardKeepToken
                    }
                    // Prefer freeing WebView memory first.
                    return .detachKeepSnapshot
                }
            }()

            guard let target else { continue }
            if target <= t.currentLevel { continue }
            decided[t.tabID] = target
            ordered.append(t.tabID)
        }

        return Decision(targetLevelByTabID: decided, orderedTabIDs: ordered)
    }
}

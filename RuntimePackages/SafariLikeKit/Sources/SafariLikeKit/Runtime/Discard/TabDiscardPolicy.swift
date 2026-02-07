import Foundation
import SafariLikeCoreKit
public enum DiscardReason: String, Sendable {
    case memoryPressure
    case backgrounding
    case oversubscription
    case thermal
}
public struct DiscardCandidate: Sendable, Equatable {
    public let tabID: UUID
    public let score: Double
    public let reason: DiscardReason
    public let details: [String: String]
    public init(tabID: UUID, score: Double, reason: DiscardReason, details: [String: String] = [:]) {
        self.tabID = tabID
        self.score = score
        self.reason = reason
        self.details = details
    }
}
public struct TabDiscardPolicy: Sendable {
    public init() {}
    public func rankCandidates(
        tabs: [TabEngagementModel],
        reason: DiscardReason,
        now: Date = Date(),
        protectedTabIDs: Set<UUID> = [],
        activeTabInFocusedPaneID: UUID? = nil
    ) -> [DiscardCandidate] {
        var out: [DiscardCandidate] = []
        out.reserveCapacity(tabs.count)
        for t in tabs {
            if protectedTabIDs.contains(t.tabID) { continue }
            if let active = activeTabInFocusedPaneID, active == t.tabID { continue }
            var score: Double = 0
            var details: [String: String] = [:]
            let visibleAge: TimeInterval = {
                guard let last = t.lastVisibleAt else { return 365 * 24 * 3600 }
                return max(0, now.timeIntervalSince(last))
            }()
            let interactionAge: TimeInterval = {
                guard let last = t.lastInteractionAt else { return 365 * 24 * 3600 }
                return max(0, now.timeIntervalSince(last))
            }()
            let visibleHours = visibleAge / 3600
            let interactionHours = interactionAge / 3600
            let baseRecency = min(200, visibleHours * 12) + min(200, interactionHours * 10)
            score += baseRecency
            details["visibleHours"] = String(format: "%.2f", visibleHours)
            details["interactionHours"] = String(format: "%.2f", interactionHours)
            let memory = max(0, t.estimatedMemoryCost)
            let memoryWeight: Double = {
                switch reason {
                case .oversubscription: return 2.0
                case .memoryPressure: return 2.6
                case .thermal: return 3.0
                case .backgrounding: return 1.2
                }
            }()
            score += Double(memory) * memoryWeight
            details["memory"] = String(memory)
            if t.isInActivePane == false {
                score += 45
                details["backgroundPane"] = "1"
            } else {
                score -= 40
                details["activePane"] = "1"
            }
            if t.backForwardDepth <= 0 {
                score += 6
            } else {
                score -= min(18, Double(t.backForwardDepth) * 2)
            }
            if t.isPlayingMedia {
                score -= 180
                details["media"] = "1"
            }
            if t.hasPendingFormEdits {
                score -= 160
                details["forms"] = "1"
            }
            if t.isPinned {
                score -= 220
                details["pinned"] = "1"
            }
            if t.isPrivate {
                score += 10
                details["private"] = "1"
            }
            if reason == .backgrounding {
                score += 18
            }
            if reason == .thermal {
                score += 30
            }
            out.append(.init(tabID: t.tabID, score: score, reason: reason, details: details))
        }
        return out.sorted { $0.score > $1.score }
    }
    public func shouldFreezeOrUnload(
        _ candidate: DiscardCandidate,
        tab: TabEngagementModel,
        now: Date = Date()
    ) -> (freeze: Bool, unload: Bool) {
        if tab.isPinned || tab.isPlayingMedia || tab.hasPendingFormEdits || tab.isInActivePane {
            return (freeze: false, unload: false)
        }
        let visibleAge: TimeInterval = {
            guard let last = tab.lastVisibleAt else { return 365 * 24 * 3600 }
            return max(0, now.timeIntervalSince(last))
        }()
        let veryStale = visibleAge > 8 * 60
        let severe = candidate.reason == .thermal || candidate.reason == .memoryPressure
        if severe, veryStale, tab.estimatedMemoryCost >= 60 {
            return (freeze: true, unload: true)
        }
        if candidate.reason == .oversubscription, veryStale, tab.estimatedMemoryCost >= 80 {
            return (freeze: true, unload: true)
        }
        return (freeze: true, unload: false)
    }
}

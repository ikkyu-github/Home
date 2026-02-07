import Foundation
import SafariLikeContracts

public enum SmartDiscardPressureLevel: Sendable {
    case normal
    case warning
    case critical
}

public struct SmartDiscardPlan: Sendable {
    public let decisionsByTabID: [UUID: DiscardDecision]
    public let suspendOrder: [UUID]
    public let discardOrder: [UUID]

    public init(
        decisionsByTabID: [UUID: DiscardDecision],
        suspendOrder: [UUID],
        discardOrder: [UUID]
    ) {
        self.decisionsByTabID = decisionsByTabID
        self.suspendOrder = suspendOrder
        self.discardOrder = discardOrder
    }
}

public protocol SmartDiscardPolicy: Sendable {
    func plan(
        tabs: [TabDiscardSignals],
        pressure: SmartDiscardPressureLevel,
        now: Date
    ) -> SmartDiscardPlan
}

public struct DefaultSmartDiscardPolicy: SmartDiscardPolicy {
    public init() {}

    public func plan(
        tabs: [TabDiscardSignals],
        pressure: SmartDiscardPressureLevel,
        now: Date
    ) -> SmartDiscardPlan {
        struct Scored {
            let tabID: UUID
            let decision: DiscardDecision
            let score: Double
            let hostKey: String
        }

        var scored: [Scored] = []
        scored.reserveCapacity(tabs.count)

        for t in tabs {
            if t.isActive || t.isPinned || t.isPlayingMedia || t.isEditingForm {
                scored.append(.init(tabID: t.tabID, decision: .keep, score: -1_000_000, hostKey: hostKey(for: t)))
                continue
            }

            if t.isForegroundRecently {
                scored.append(.init(tabID: t.tabID, decision: .keep, score: -10_000, hostKey: hostKey(for: t)))
                continue
            }

            let ageSec = max(0, now.timeIntervalSince(t.lastInteractionTime))
            let ageMin = ageSec / 60.0

            let ageScore = min(240, ageMin * 6.0)
            let memScore = min(260, Double(max(0, t.memoryCostEstimate)) * 2.6)
            let depthPenalty = min(48, Double(max(0, t.navigationDepth)) * 4.0)

            var categoryBias: Double = 0
            switch t.siteCategory {
            case .doc:
                categoryBias += 35
            case .unknown:
                categoryBias += 10
            case .social:
                categoryBias -= 25
            case .video:
                categoryBias -= 40
            @unknown default:
                categoryBias += 10
            }

            var pressureBias: Double = 0
            switch pressure {
            case .normal:
                pressureBias += 0
            case .warning:
                pressureBias += 60
            case .critical:
                pressureBias += 140
            }

            let rawScore = ageScore + memScore + categoryBias + pressureBias - depthPenalty

            let (decision, decisionScore) = decideOne(
                rawScore: rawScore,
                ageMinutes: ageMin,
                tab: t,
                pressure: pressure
            )

            scored.append(.init(tabID: t.tabID, decision: decision, score: decisionScore, hostKey: hostKey(for: t)))
        }

        // Prefer discarding same-origin tabs together (when eligible).
        var decisionsByID: [UUID: DiscardDecision] = Dictionary(uniqueKeysWithValues: scored.map { ($0.tabID, $0.decision) })
        let discardHosts = Set(scored.filter { $0.decision == .discard }.map { $0.hostKey }.filter { !$0.isEmpty })
        if discardHosts.isEmpty == false {
            for item in scored where discardHosts.contains(item.hostKey) {
                if decisionsByID[item.tabID] == .keep {
                    // Upgrade keep->discard only if not protected (already filtered above).
                    decisionsByID[item.tabID] = .discard
                }
            }
        }

        let discardOrder = scored
            .filter { decisionsByID[$0.tabID] == .discard }
            .sorted { $0.score > $1.score }
            .map { $0.tabID }

        let suspendOrder = scored
            .filter { decisionsByID[$0.tabID] == .suspend }
            .sorted { $0.score > $1.score }
            .map { $0.tabID }

        return SmartDiscardPlan(decisionsByTabID: decisionsByID, suspendOrder: suspendOrder, discardOrder: discardOrder)
    }

    private func decideOne(
        rawScore: Double,
        ageMinutes: Double,
        tab: TabDiscardSignals,
        pressure: SmartDiscardPressureLevel
    ) -> (DiscardDecision, Double) {
        // Escalation: keep -> suspend -> discard.
        switch pressure {
        case .normal:
            if ageMinutes >= 45, tab.siteCategory == .doc { return (.discard, rawScore + 20) }
            if ageMinutes >= 90, tab.siteCategory == .unknown, tab.memoryCostEstimate >= 70 { return (.discard, rawScore) }

            if ageMinutes >= 30, (tab.siteCategory == .video || tab.siteCategory == .social), tab.memoryCostEstimate >= 50 {
                return (.suspend, rawScore)
            }
            return (.keep, rawScore)

        case .warning:
            if (tab.siteCategory == .video || tab.siteCategory == .social) {
                if ageMinutes >= 6 { return (.suspend, rawScore + 30) }
                return (.keep, rawScore)
            }

            if ageMinutes >= 10 { return (.discard, rawScore + 30) }
            if ageMinutes >= 4, tab.memoryCostEstimate >= 60 { return (.suspend, rawScore) }
            return (.keep, rawScore)

        case .critical:
            if (tab.siteCategory == .video || tab.siteCategory == .social) {
                if ageMinutes >= 2 { return (.suspend, rawScore + 60) }
                return (.keep, rawScore)
            }

            if ageMinutes >= 2 { return (.discard, rawScore + 80) }
            return (.suspend, rawScore)
        }
    }

    private func hostKey(for tab: TabDiscardSignals) -> String {
        guard let host = tab.lastCommittedURL?.host?.lowercased(), host.isEmpty == false else {
            return ""
        }
        return host
    }
}

import Foundation

/// Extension to TabDiscardPolicy for per-site heuristics integration.
///
/// Allows the discard policy to be adjusted based on site-specific heuristics.
/// This maintains pure policy computation while allowing policy to vary per site.
public extension TabDiscardPolicy {
    
    /// Site-aware descriptor that includes heuristics-derived policy.
    struct SiteAwareTabDescriptor: Sendable, Equatable {
        /// Base tab descriptor
        public var tab: TabDescriptor
        
        /// Site key for heuristics lookup (eTLD+1)
        public var siteKey: String
        
        /// Current site policy (computed from heuristics)
        public var sitePolicy: SitePolicy
        
        public init(
            tab: TabDescriptor,
            siteKey: String,
            sitePolicy: SitePolicy = .default
        ) {
            self.tab = tab
            self.siteKey = siteKey
            self.sitePolicy = sitePolicy
        }
    }
    
    /// Enhanced input that includes site-aware descriptors.
    struct SiteAwareInput: Sendable, Equatable {
        public var trigger: TabDiscardTrigger
        public var now: Date
        public var tabs: [SiteAwareTabDescriptor]
        
        public init(trigger: TabDiscardTrigger, now: Date, tabs: [SiteAwareTabDescriptor]) {
            self.trigger = trigger
            self.now = now
            self.tabs = tabs
        }
    }
    
    /// Make a decision using site-aware heuristics.
    /// Modulates aggressiveness based on SitePolicy.discardAggressiveness.
    func decideSiteAware(_ input: SiteAwareInput) -> Decision {
        let now = input.now
        
        // Always protect visible tabs at level 0 (keep attached).
        let visible = Set(input.tabs.compactMap { $0.tab.isVisible ? $0.tab.tabID : nil })
        
        // Build candidates with site-aware scoring.
        var candidates: [(id: UUID, score: Double, descriptor: TabDescriptor, sitePolicy: SitePolicy)] = []
        candidates.reserveCapacity(input.tabs.count)
        
        for t in input.tabs {
            if visible.contains(t.tab.tabID) { continue }
            if t.tab.isPinned || t.tab.isUserLocked { continue }
            
            // Base resource score
            let baseScore = TabResourceScore.score(
                .init(
                    tabID: t.tab.tabID,
                    lastActiveAt: t.tab.lastActiveAt,
                    isPinned: t.tab.isPinned,
                    isUserLocked: t.tab.isUserLocked,
                    hasUnsavedForm: t.tab.hasUnsavedForm,
                    isPlayingMedia: t.tab.isPlayingMedia,
                    memoryCostEstimate: t.tab.memoryCostEstimate
                ),
                now: now,
                config: config
            )
            
            // Modulate score based on site policy
            // aggressiveness 3: increase score (more likely to discard)
            // aggressiveness 0: decrease score (protect it)
            let aggrFactor = Double(t.sitePolicy.discardAggressiveness) / 1.5
            let adjustedScore = baseScore * aggrFactor
            
            candidates.append((t.tab.tabID, adjustedScore, t.tab, t.sitePolicy))
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
            let sitePolicy = c.sitePolicy
            let age = inactiveFor(t)
            
            // Skip if sensitive data protection requested
            if t.hasUnsavedForm || t.isPlayingMedia {
                continue
            }
            
            // Respect site policy aggressiveness = 0 (never discard)
            if sitePolicy.discardAggressiveness == 0 {
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

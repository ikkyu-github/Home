import Foundation

/// Pure, deterministic engine for computing site policies from heuristics.
///
/// Contract:
/// - No side effects: same input always produces same output
/// - Thread-safe: all functions are immutable
/// - Used by TabDiscardPolicy, restore logic, and UI for decision-making
///
/// Designed to be called frequently without contention (pure computations).
public struct HeuristicsEngine: Sendable {
    
    // MARK: - Thresholds (tunable constants)
    
    public struct Thresholds: Sendable {
        /// Load time threshold (ms) to consider site "fast"
        public var fastLoadTimeMs: Double = 1000
        
        /// Load time threshold (ms) to consider site "slow"
        public var slowLoadTimeMs: Double = 5000
        
        /// Crash count threshold to mark site as problematic
        public var crashThreshold: Int = 3
        
        /// Memory hotness threshold to trigger aggressive discard
        public var heavyMemoryThreshold: Int = 70
        
        /// Restore failure count threshold to reduce trust
        public var restoreFailureThreshold: Int = 2
        
        public init(
            fastLoadTimeMs: Double = 1000,
            slowLoadTimeMs: Double = 5000,
            crashThreshold: Int = 3,
            heavyMemoryThreshold: Int = 70,
            restoreFailureThreshold: Int = 2
        ) {
            self.fastLoadTimeMs = fastLoadTimeMs
            self.slowLoadTimeMs = slowLoadTimeMs
            self.crashThreshold = crashThreshold
            self.heavyMemoryThreshold = heavyMemoryThreshold
            self.restoreFailureThreshold = restoreFailureThreshold
        }
    }
    
    public let thresholds: Thresholds
    
    public init(thresholds: Thresholds = .init()) {
        self.thresholds = thresholds
    }
    
    // MARK: - Pure Computation API
    
    /// Update heuristics model from new metrics (pure).
    /// Used to incorporate fresh observation into the model.
    public func update(
        model: SiteHeuristicsModel,
        with metrics: Metrics
    ) -> SiteHeuristicsModel {
        var updated = model
        
        if let loadTimeMs = metrics.loadTimeMs {
            // Exponential moving average: 80% old, 20% new
            if updated.avgLoadTimeMs == 0 {
                updated.avgLoadTimeMs = loadTimeMs
            } else {
                updated.avgLoadTimeMs = updated.avgLoadTimeMs * 0.8 + loadTimeMs * 0.2
            }
        }
        
        if metrics.didCrash {
            updated.crashCount = min(100, updated.crashCount + 1)
            updated.lastCrashAt = metrics.observedAt
            // Crashes increase memory hotness
            updated.memoryHotnessScore = min(100, updated.memoryHotnessScore + 15)
        }
        
        if metrics.restoreFailed {
            updated.restoreFailureCount = min(100, updated.restoreFailureCount + 1)
        }
        
        if metrics.isMediaHeavy {
            updated.isMediaHeavy = true
        }
        
        if let memoryScore = metrics.memoryHotnessScore {
            // Take the higher of current or observed score
            updated.memoryHotnessScore = max(updated.memoryHotnessScore, memoryScore)
        }

        updated.lastSeenAt = metrics.observedAt
        
        return updated
    }
    
    /// Compute policy from heuristics (pure).
    /// This is the core decision function—called frequently, must be fast.
    public func computePolicy(from model: SiteHeuristicsModel) -> SitePolicy {
        let isCrashing = model.crashCount >= thresholds.crashThreshold
        let isSlowLoading = model.avgLoadTimeMs > thresholds.slowLoadTimeMs
        let isHeavyMemory = model.memoryHotnessScore > thresholds.heavyMemoryThreshold
        let hasRestoreIssues = model.restoreFailureCount >= thresholds.restoreFailureThreshold
        let isSensitive = model.privacyFlags.requiresPersistentStorage || model.privacyFlags.isSensitive
        
        // Determine base aggressiveness
        var discardAggressiveness = 2 // default
        if isSensitive {
            discardAggressiveness = 0 // never discard sensitive sites
        } else if isCrashing || isHeavyMemory || isSlowLoading {
            discardAggressiveness = 3 // aggressive discard
        } else if model.avgLoadTimeMs < thresholds.fastLoadTimeMs && model.crashCount == 0 {
            discardAggressiveness = 1 // less aggressive for stable sites
        }
        
        // Determine if we can prewarm
        let canPrewarm = !isSensitive
            && !isCrashing
            && !isHeavyMemory
            && !hasRestoreIssues
            && model.avgLoadTimeMs < thresholds.slowLoadTimeMs
            && model.crashCount == 0
        
        // Navigation throttle based on stability
        let navigationThrottle: SitePolicy.NavigationThrottle
        if isCrashing || isHeavyMemory {
            navigationThrottle = .high
        } else if hasRestoreIssues {
            navigationThrottle = .normal
        } else if model.avgLoadTimeMs < thresholds.fastLoadTimeMs {
            navigationThrottle = .low
        } else {
            navigationThrottle = .normal
        }
        
        // Thumbnail capture policy
        let thumbnailCapturePolicy: SitePolicy.ThumbnailCapturePolicy
        if isHeavyMemory {
            thumbnailCapturePolicy = .never // Save memory
        } else if canPrewarm {
            thumbnailCapturePolicy = .always // Good candidates for preview
        } else {
            thumbnailCapturePolicy = .onDemand // Default
        }
        
        return SitePolicy(
            allowPrewarmWebView: canPrewarm,
            discardAggressiveness: discardAggressiveness,
            navigationThrottle: navigationThrottle,
            thumbnailCapturePolicy: thumbnailCapturePolicy
        )
    }
    
    // MARK: - Batch Operations
    
    /// Compute policies for multiple sites (pure batch operation).
    public func computePolicies(
        from models: [String: SiteHeuristicsModel]
    ) -> [String: SitePolicy] {
        models.mapValues { computePolicy(from: $0) }
    }
    
    // MARK: - Diagnostic/Scoring
    
    /// Health score for a site (0-100, higher is better).
    /// Used for UI indicators and debugging.
    public func healthScore(from model: SiteHeuristicsModel) -> Int {
        var score = 100
        
        // Deduct for crashes
        score -= model.crashCount * 10
        
        // Deduct for slow loading
        if model.avgLoadTimeMs > thresholds.slowLoadTimeMs {
            score -= 20
        } else if model.avgLoadTimeMs > thresholds.fastLoadTimeMs {
            score -= 10
        }
        
        // Deduct for memory issues
        score -= (model.memoryHotnessScore / 2)
        
        // Deduct for restore failures
        score -= model.restoreFailureCount * 5
        
        // Bonus for media-heavy (legitimate use case)
        if model.isMediaHeavy {
            score -= 5
        }
        
        // Clamp to 0-100
        return max(0, min(100, score))
    }
    
    /// Determine if a site is "risky" for important operations (pure).
    public func isRisky(model: SiteHeuristicsModel) -> Bool {
        model.crashCount >= thresholds.crashThreshold
            || model.memoryHotnessScore > thresholds.heavyMemoryThreshold
            || model.restoreFailureCount >= thresholds.restoreFailureThreshold
    }
}

// MARK: - Metrics Input

public extension HeuristicsEngine {
    
    /// Metrics fed from the runtime (SafariLikeCoreKit, WebKit observers, etc.)
    struct Metrics: Sendable {
        /// Timestamp associated with this observation.
        /// Caller provides this to keep the engine pure/deterministic.
        public var observedAt: Date

        /// Navigation commit time in milliseconds
        public var loadTimeMs: Double?
        
        /// Web process crashed or was terminated
        public var didCrash: Bool
        
        /// Restore/navigation failed
        public var restoreFailed: Bool
        
        /// Site is playing media
        public var isMediaHeavy: Bool
        
        /// Direct memory hotness observation (0-100)
        public var memoryHotnessScore: Int?
        
        public init(
            observedAt: Date,
            loadTimeMs: Double? = nil,
            didCrash: Bool = false,
            restoreFailed: Bool = false,
            isMediaHeavy: Bool = false,
            memoryHotnessScore: Int? = nil
        ) {
            self.observedAt = observedAt
            self.loadTimeMs = loadTimeMs
            self.didCrash = didCrash
            self.restoreFailed = restoreFailed
            self.isMediaHeavy = isMediaHeavy
            self.memoryHotnessScore = memoryHotnessScore
        }
    }
}

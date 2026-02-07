import Foundation

/// Computed policy for a site, derived from SiteHeuristicsModel.
/// Used by TabDiscardPolicy, restore logic, and other resource managers.
///
/// This is a pure output of HeuristicsEngine—no side effects.
public struct SitePolicy: Equatable, Sendable {
    
    // MARK: - Prewarming & Restore
    
    /// Whether to proactively prewarm a WebView before restore/navigation
    /// Set to true for frequently-visited, fast-loading sites.
    public var allowPrewarmWebView: Bool
    
    // MARK: - Tab Discard Strategy
    
    /// Aggressiveness of discarding tabs from this site: 0–3
    /// - 0: Never discard (e.g., sensitive, persistent storage)
    /// - 1: Discard only under severe memory pressure
    /// - 2: Normal discard policy (default)
    /// - 3: Aggressive discard (heavy/crashing sites)
    public var discardAggressiveness: Int // 0-3
    
    // MARK: - Navigation Behavior
    
    public enum NavigationThrottle: String, Sendable {
        case low        // No throttle, prioritize responsiveness
        case normal     // Standard throttle
        case high       // Heavy throttle, prioritize stability/memory
    }
    
    /// Throttle level for navigations to this site
    public var navigationThrottle: NavigationThrottle
    
    // MARK: - Thumbnail Capture
    
    public enum ThumbnailCapturePolicy: String, Sendable {
        case always     // Always capture thumbnails for restore preview
        case onDemand   // Capture only when user browses tabs
        case never      // Skip (save memory/battery)
    }
    
    public var thumbnailCapturePolicy: ThumbnailCapturePolicy
    
    // MARK: - Plugin Boundary Allowances (Future)
    
    /// Reserved for future: allow certain plugins near this site
    public var pluginBoundaryAllowances: [String]
    
    // MARK: - Initialization
    
    public init(
        allowPrewarmWebView: Bool = false,
        discardAggressiveness: Int = 2,
        navigationThrottle: NavigationThrottle = .normal,
        thumbnailCapturePolicy: ThumbnailCapturePolicy = .onDemand,
        pluginBoundaryAllowances: [String] = []
    ) {
        self.allowPrewarmWebView = allowPrewarmWebView
        self.discardAggressiveness = min(3, max(0, discardAggressiveness))
        self.navigationThrottle = navigationThrottle
        self.thumbnailCapturePolicy = thumbnailCapturePolicy
        self.pluginBoundaryAllowances = pluginBoundaryAllowances
    }
    
    // MARK: - Default Policies
    
    /// Default policy: safe, moderate behavior
    public static let `default` = SitePolicy()
    
    /// Policy for sensitive/financial sites: minimal discard, no prewarm
    public static let sensitive = SitePolicy(
        allowPrewarmWebView: false,
        discardAggressiveness: 0,
        navigationThrottle: .normal,
        thumbnailCapturePolicy: .onDemand
    )
    
    /// Policy for heavy/problematic sites: aggressive discard
    public static let aggressive = SitePolicy(
        allowPrewarmWebView: false,
        discardAggressiveness: 3,
        navigationThrottle: .high,
        thumbnailCapturePolicy: .onDemand
    )
    
    /// Policy for frequently-visited, well-behaved sites
    public static let trusted = SitePolicy(
        allowPrewarmWebView: true,
        discardAggressiveness: 1,
        navigationThrottle: .low,
        thumbnailCapturePolicy: .always
    )
}

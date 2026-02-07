import Foundation

/// Per-site heuristics and metrics for intelligent resource management.
///
/// Key format: eTLD+1 (e.g., "example.com") or normalized host for private/IP sites.
/// Used to compute dynamic SitePolicy for tabs and restore operations.
public struct SiteHeuristicsModel: Codable, Equatable, Sendable {
    
    /// Unique site identifier: eTLD+1 or normalized host
    public var siteKey: String
    
    // MARK: - Performance Metrics
    
    /// Average page load time (in milliseconds) over sliding window
    public var avgLoadTimeMs: Double
    
    /// Count of crashes/web process terminations in current window
    public var crashCount: Int

    /// Timestamp of the most recent crash/web content process termination.
    public var lastCrashAt: Date?
    
    /// Count of restore failures (failed navigation) in current window
    public var restoreFailureCount: Int
    
    // MARK: - Memory Heuristics
    
    /// Memory "hotness" score: 0-100 indicating relative memory pressure
    /// - 0-30: Light (minimal memory footprint)
    /// - 31-60: Normal (typical memory usage)
    /// - 61-100: Heavy (aggressive memory usage or history of crashes)
    public var memoryHotnessScore: Int
    
    /// Indicates site uses significant media resources (video/audio playback)
    public var isMediaHeavy: Bool
    
    // MARK: - User Preferences
    
    /// User's desktop/mobile mode preference for this site (if set)
    public var prefersDesktopMode: Bool?
    
    /// Privacy-related flags and restrictions
    public struct PrivacyFlags: Codable, Equatable, Sendable {
        /// Site is known to track across sites (requires isolation)
        public var isTracking: Bool
        
        /// Site requires persistent storage (do not discard without user confirmation)
        public var requiresPersistentStorage: Bool
        
        /// Site has sensitive data (extra caution on restore/reload)
        public var isSensitive: Bool
        
        public init(
            isTracking: Bool = false,
            requiresPersistentStorage: Bool = false,
            isSensitive: Bool = false
        ) {
            self.isTracking = isTracking
            self.requiresPersistentStorage = requiresPersistentStorage
            self.isSensitive = isSensitive
        }
    }
    
    public var privacyFlags: PrivacyFlags
    
    // MARK: - Temporal
    
    /// Timestamp when this site was last visited
    public var lastSeenAt: Date
    
    /// Schema version for migration support
    public internal(set) var schemaVersion: Int = 1
    
    // MARK: - Initialization
    
    public init(
        siteKey: String,
        avgLoadTimeMs: Double = 0,
        crashCount: Int = 0,
        lastCrashAt: Date? = nil,
        restoreFailureCount: Int = 0,
        memoryHotnessScore: Int = 30,
        isMediaHeavy: Bool = false,
        prefersDesktopMode: Bool? = nil,
        privacyFlags: PrivacyFlags = .init(),
        lastSeenAt: Date = Date()
    ) {
        self.siteKey = siteKey
        self.avgLoadTimeMs = avgLoadTimeMs
        self.crashCount = crashCount
        self.lastCrashAt = lastCrashAt
        self.restoreFailureCount = restoreFailureCount
        self.memoryHotnessScore = memoryHotnessScore
        self.isMediaHeavy = isMediaHeavy
        self.prefersDesktopMode = prefersDesktopMode
        self.privacyFlags = privacyFlags
        self.lastSeenAt = lastSeenAt
    }
}

// MARK: - Site Key Normalization

public extension SiteHeuristicsModel {
    /// Compute normalized site key from URL.
    /// Returns eTLD+1 (e.g., "example.com") or host for special cases.
    static func normalizeSiteKey(from url: URL) -> String {
        // For now, extract host and attempt eTLD+1
        // In production, use a proper eTLD library or regex
        if let host = url.host {
            return normalizeHost(host)
        }
        return "unknown"
    }
    
    private static func normalizeHost(_ host: String) -> String {
        let lower = host.lowercased()
        
        // Special cases: localhost, IP addresses
        if lower == "localhost" || lower.starts(with: "127.") || lower.starts(with: "192.168.") {
            return lower
        }
        
        // Remove www. prefix for cleaner keys
        let trimmed = lower.starts(with: "www.") ? String(lower.dropFirst(4)) : lower
        
        // Simple eTLD+1: take last 2 components (works for most .com/.co.uk cases)
        let components = trimmed.split(separator: ".").map(String.init)
        if components.count > 2 {
            return (components[components.count - 2] + "." + components[components.count - 1])
        }
        
        return trimmed
    }
}

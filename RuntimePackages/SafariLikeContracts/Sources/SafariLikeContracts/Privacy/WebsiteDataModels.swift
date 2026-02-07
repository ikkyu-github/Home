import Foundation

// MARK: - Website Data

/// Website data profile.
///
/// - `regular`: Persistent website data.
/// - `private`: Non-persistent website data (best-effort; may not be enumerable/clearable).
public enum WebsiteDataProfile: String, Codable, Sendable {
    case regular
    case `private`
}

/// Stable identifier for a website data type.
///
/// Notes:
/// - The concrete source of these type identifiers is platform-specific.
/// - On Apple platforms, these map to WebKit website data type identifiers.
public struct WebsiteDataType: RawRepresentable, Hashable, Codable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    // Common, cross-platform-ish buckets. Platform adapters may emit additional types.
    public static let cookies = WebsiteDataType(rawValue: "cookies")
    public static let diskCache = WebsiteDataType(rawValue: "diskCache")
    public static let memoryCache = WebsiteDataType(rawValue: "memoryCache")
    public static let localStorage = WebsiteDataType(rawValue: "localStorage")
    public static let sessionStorage = WebsiteDataType(rawValue: "sessionStorage")
    public static let indexedDB = WebsiteDataType(rawValue: "indexedDB")
    public static let serviceWorkers = WebsiteDataType(rawValue: "serviceWorkers")
    public static let offlineWebAppCache = WebsiteDataType(rawValue: "offlineWebAppCache")
}

/// A single website's stored data record.
///
/// This is a platform-independent representation of what the runtime can enumerate.
public struct WebsiteDataRecord: Identifiable, Hashable, Codable, Sendable {
    public let id: String

    /// Display name as provided by the runtime adapter (often a host).
    public let displayName: String

    /// Best-effort site key derived from displayName.
    public let siteKey: SiteKey

    /// Best-effort data types known to be present for this site.
    public let dataTypes: Set<WebsiteDataType>

    /// Optional best-effort size estimate in bytes.
    /// Most platform adapters will not be able to provide this.
    public let approximateSizeBytes: Int?

    public init(
        displayName: String,
        siteKey: SiteKey,
        dataTypes: Set<WebsiteDataType>,
        approximateSizeBytes: Int? = nil
    ) {
        self.displayName = displayName
        self.siteKey = siteKey
        self.dataTypes = dataTypes
        self.approximateSizeBytes = approximateSizeBytes
        self.id = siteKey.storageKey
    }
}

/// Scope for clearing website data.
public enum ClearWebsiteDataScope: Codable, Sendable, Hashable {
    case all(timeRange: ClearDataTimeRange)
    case site(siteKey: SiteKey)
}

/// Request describing which website data to clear.
public struct ClearWebsiteDataRequest: Codable, Sendable, Hashable {
    public let profile: WebsiteDataProfile
    public let scope: ClearWebsiteDataScope

    /// When empty, adapters should treat it as "all supported types".
    public let dataTypes: Set<WebsiteDataType>

    public init(profile: WebsiteDataProfile, scope: ClearWebsiteDataScope, dataTypes: Set<WebsiteDataType> = []) {
        self.profile = profile
        self.scope = scope
        self.dataTypes = dataTypes
    }
}

// MARK: - Privacy Report

public struct PermissionDecisionCounts: Codable, Sendable, Hashable {
    public var allow: Int
    public var deny: Int
    public var ask: Int

    public init(allow: Int = 0, deny: Int = 0, ask: Int = 0) {
        self.allow = allow
        self.deny = deny
        self.ask = ask
    }
}

public struct PermissionSummaryItem: Codable, Sendable, Hashable {
    public let permissionType: PermissionType
    public let counts: PermissionDecisionCounts

    public init(permissionType: PermissionType, counts: PermissionDecisionCounts) {
        self.permissionType = permissionType
        self.counts = counts
    }
}

/// A Privacy Report-style snapshot.
///
/// Deterministic and layer-safe: generated from stores/services without touching UI state.
public struct PrivacyReportSnapshot: Codable, Sendable, Hashable {
    public let generatedAt: Date
    public let profile: WebsiteDataProfile

    /// Best-effort count of distinct sites with stored website data.
    public let sitesWithWebsiteDataCount: Int

    /// Best-effort count of content blocker exceptions.
    ///
    /// Current semantics: sites where per-site preferences explicitly disable content blocking.
    public let contentBlockerExceptionsCount: Int

    /// Per-permission decision counts from the site settings store.
    public let permissionSummaries: [PermissionSummaryItem]

    /// Optional best-effort trackers-blocked count.
    /// Not available without a tracker instrumentation pipeline.
    public let trackersBlockedCount: Int?

    public init(
        generatedAt: Date,
        profile: WebsiteDataProfile,
        sitesWithWebsiteDataCount: Int,
        contentBlockerExceptionsCount: Int,
        permissionSummaries: [PermissionSummaryItem],
        trackersBlockedCount: Int?
    ) {
        self.generatedAt = generatedAt
        self.profile = profile
        self.sitesWithWebsiteDataCount = sitesWithWebsiteDataCount
        self.contentBlockerExceptionsCount = contentBlockerExceptionsCount
        self.permissionSummaries = permissionSummaries
        self.trackersBlockedCount = trackersBlockedCount
    }
}

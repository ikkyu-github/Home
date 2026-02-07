import Foundation

/// Safari-like website data policy.
///
/// Design goals:
/// - Layer-safe (no WebKit import).
/// - Scene-injectable (policy is owned by the scene/runtime composition root).
/// - Testable (pure data; deterministic defaults).
public struct WebsiteDataPolicy: Codable, Sendable, Hashable {
    public enum Mode: String, Codable, Sendable {
        case normal
        case `private`
    }

    public enum Persistence: String, Codable, Sendable {
        case persistent
        case nonPersistent
    }

    public struct CleanupRules: Codable, Sendable, Hashable {
        /// Maximum age in days (best-effort).
        ///
        /// Note: some platform adapters cannot remove “older than X days” per-site; they may
        /// implement this as a cadence-gated clearing of selected data types.
        public var maxAgeDays: Int

        /// Best-effort disk budget in MB.
        ///
        /// Note: WebKit does not provide reliable per-type/per-site sizes, so this is advisory.
        public var maxDiskMB: Int?

        /// Minimum time interval (seconds) between cleanups.
        public var cadenceSeconds: TimeInterval

        /// Data types eligible for periodic cleanup in normal mode.
        ///
        /// Defaults are conservative (cache-like types); cookies/storage are kept stable.
        public var eligibleTypes: Set<WebsiteDataType>

        public init(
            maxAgeDays: Int,
            maxDiskMB: Int?,
            cadenceSeconds: TimeInterval,
            eligibleTypes: Set<WebsiteDataType>
        ) {
            self.maxAgeDays = max(0, maxAgeDays)
            self.maxDiskMB = maxDiskMB
            self.cadenceSeconds = max(0, cadenceSeconds)
            self.eligibleTypes = eligibleTypes
        }

        public static let `default` = CleanupRules(
            maxAgeDays: 7,
            maxDiskMB: 250,
            cadenceSeconds: 24 * 60 * 60,
            eligibleTypes: [
                .diskCache,
                .memoryCache,
                .offlineWebAppCache,
                .serviceWorkers
            ]
        )
    }

    public struct DomainRules: Codable, Sendable, Hashable {
        /// Optional allow-list for future policies (e.g. stricter persistence).
        public var allowList: [String]
        /// Optional deny-list for future policies.
        public var denyList: [String]

        public init(allowList: [String] = [], denyList: [String] = []) {
            self.allowList = allowList
            self.denyList = denyList
        }

        public static let `default` = DomainRules()
    }

    public var mode: Mode
    public var persistence: Persistence
    public var cleanup: CleanupRules
    public var domainRules: DomainRules

    public init(
        mode: Mode,
        persistence: Persistence,
        cleanup: CleanupRules = .default,
        domainRules: DomainRules = .default
    ) {
        self.mode = mode
        self.persistence = persistence
        self.cleanup = cleanup
        self.domainRules = domainRules
    }

    public static let normalDefault = WebsiteDataPolicy(
        mode: .normal,
        persistence: .persistent,
        cleanup: .default,
        domainRules: .default
    )

    public static let privateDefault = WebsiteDataPolicy(
        mode: .private,
        persistence: .nonPersistent,
        cleanup: .default,
        domainRules: .default
    )
}

/// Per-scene website data policy set.
public struct WebsiteDataPolicySet: Codable, Sendable, Hashable {
    public var normal: WebsiteDataPolicy
    public var `private`: WebsiteDataPolicy

    public init(normal: WebsiteDataPolicy = .normalDefault, private: WebsiteDataPolicy = .privateDefault) {
        self.normal = normal
        self.private = `private`
    }

    public static let `default` = WebsiteDataPolicySet()
}

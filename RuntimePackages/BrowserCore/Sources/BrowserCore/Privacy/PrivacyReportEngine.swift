import Foundation
import SafariLikeContracts

public struct PrivacyReportEngineDependencies {
    public let websiteDataService: any WebsiteDataServicing
    public let siteSettingsStore: SiteSettingsStore
    public let websitePreferencesStore: WebsitePreferencesProviding
    public let now: @Sendable () -> Date
    public let trackersBlockedCountProvider: (@Sendable (WebsiteDataProfile) async -> Int?)?

    public init(
        websiteDataService: any WebsiteDataServicing,
        siteSettingsStore: SiteSettingsStore,
        websitePreferencesStore: WebsitePreferencesProviding,
        now: @escaping @Sendable () -> Date = { Date() },
        trackersBlockedCountProvider: (@Sendable (WebsiteDataProfile) async -> Int?)? = nil
    ) {
        self.websiteDataService = websiteDataService
        self.siteSettingsStore = siteSettingsStore
        self.websitePreferencesStore = websitePreferencesStore
        self.now = now
        self.trackersBlockedCountProvider = trackersBlockedCountProvider
    }
}

/// Aggregates privacy signals into a Safari-style snapshot.
public struct PrivacyReportEngine {
    private let deps: PrivacyReportEngineDependencies

    public init(dependencies: PrivacyReportEngineDependencies) {
        self.deps = dependencies
    }

    public func generateSnapshot(profile: WebsiteDataProfile) async -> PrivacyReportSnapshot {
        let generatedAt = deps.now()

        let sitesWithWebsiteDataCount: Int
        do {
            let records = try await deps.websiteDataService.fetchRecords(profile: profile)
            sitesWithWebsiteDataCount = Set(records.map { $0.siteKey.storageKey }).count
        } catch {
            sitesWithWebsiteDataCount = 0
        }

        let contentBlockerExceptionsCount: Int = {
            let prefs = deps.websitePreferencesStore.allPreferences()
            // Semantics: a "custom" exception is explicitly disabling content blocking.
            // WebsitePreferences defaults to enabled (Safari-like). Only count explicit disables.
            return prefs.filter { $0.contentBlockerEnabled == false }.count
        }()

        let trackersBlockedCount: Int? = await deps.trackersBlockedCountProvider?(profile)

        let stats = await deps.siteSettingsStore.statisticsSnapshot()

        return PrivacyReportSnapshot(
            generatedAt: generatedAt,
            profile: profile,
            sitesWithWebsiteDataCount: sitesWithWebsiteDataCount,
            contentBlockerExceptionsCount: contentBlockerExceptionsCount,
            permissionSummaries: stats.permissionSummaries,
            trackersBlockedCount: trackersBlockedCount
        )
    }
}

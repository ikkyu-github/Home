import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class PrivacyReportEngineTests: XCTestCase {

    private final class InMemoryWebsitePreferencesStore: WebsitePreferencesProviding {
        private var byDomain: [String: WebsitePreferences] = [:]

        func getPreferences(for domain: String) -> WebsitePreferences {
            let key = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return byDomain[key] ?? WebsitePreferences.defaults(for: key)
        }

        func setPreferences(_ preferences: WebsitePreferences, for domain: String) {
            let key = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            byDomain[key] = preferences
        }

        func allPreferences() -> [WebsitePreferences] {
            Array(byDomain.values)
        }

        func clearPreferences(for domain: String) {
            let key = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            byDomain.removeValue(forKey: key)
        }

        func clearAllPreferences() {
            byDomain.removeAll()
        }
    }

    private actor MockWebsiteDataService: WebsiteDataServicing {
        var recordsByProfile: [WebsiteDataProfile: [WebsiteDataRecord]] = [:]
        var supportedTypesByProfile: [WebsiteDataProfile: Set<WebsiteDataType>] = [:]

        func setRecords(_ records: [WebsiteDataRecord], for profile: WebsiteDataProfile) {
            recordsByProfile[profile] = records
        }

        func fetchRecords(profile: WebsiteDataProfile) async throws -> [WebsiteDataRecord] {
            recordsByProfile[profile] ?? []
        }

        func clear(request: ClearWebsiteDataRequest) async throws {
            // No-op for tests.
        }

        func supportedDataTypes(profile: WebsiteDataProfile) async -> Set<WebsiteDataType> {
            supportedTypesByProfile[profile] ?? []
        }
    }

    func testGenerateSnapshot_countsSitesWithWebsiteDataDistinctBySiteKey() async {
        let service = MockWebsiteDataService()

        await service.setRecords([
            WebsiteDataRecord(displayName: "a.example.com", siteKey: SiteKey(host: "a.example.com"), dataTypes: [.cookies]),
            WebsiteDataRecord(displayName: "example.com", siteKey: SiteKey(host: "example.com"), dataTypes: [.diskCache]),
            // Same eTLD+1, but SiteKey.storageKey collapses to eTLD+1.
            WebsiteDataRecord(displayName: "b.example.com", siteKey: SiteKey(host: "b.example.com"), dataTypes: [.localStorage])
        ], for: .regular)

        let siteSettings = SiteSettingsStore(persistence: .memory)
        await siteSettings.setDecision(.allow, for: SiteKey(host: "example.com"), type: .camera)
        await siteSettings.setDecision(.deny, for: SiteKey(host: "example.com"), type: .location)

        let prefsStore = InMemoryWebsitePreferencesStore()
        var prefs = prefsStore.getPreferences(for: "example.com")
        prefs.contentBlockerEnabled = false
        prefsStore.setPreferences(prefs, for: "example.com")

        let engine = PrivacyReportEngine(
            dependencies: .init(
                websiteDataService: service,
                siteSettingsStore: siteSettings,
                websitePreferencesStore: prefsStore,
                now: { Date(timeIntervalSince1970: 1) }
            )
        )

        let snapshot = await engine.generateSnapshot(profile: .regular)
        XCTAssertEqual(snapshot.profile, .regular)
        XCTAssertEqual(snapshot.sitesWithWebsiteDataCount, 1)
        XCTAssertEqual(snapshot.contentBlockerExceptionsCount, 1)
        XCTAssertEqual(snapshot.generatedAt.timeIntervalSince1970, 1, accuracy: 0.0001)

        let camera = snapshot.permissionSummaries.first(where: { $0.permissionType == .camera })
        XCTAssertEqual(camera?.counts.allow, 1)

        let location = snapshot.permissionSummaries.first(where: { $0.permissionType == .location })
        XCTAssertEqual(location?.counts.deny, 1)
    }
}

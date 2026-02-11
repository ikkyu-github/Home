import XCTest
@testable import BrowserCore
import SafariLikeContracts

@MainActor
final class FormFillPolicyEngineTests: XCTestCase {

    @MainActor
    private final class InMemoryWebsitePreferencesStore: WebsitePreferencesProviding {
        private var byDomain: [String: WebsitePreferences] = [:]

        func getPreferences(for domain: String) -> WebsitePreferences {
            byDomain[domain] ?? WebsitePreferences.defaults(for: domain)
        }

        func setPreferences(_ preferences: WebsitePreferences, for domain: String) {
            byDomain[domain] = preferences
        }

        func allPreferences() -> [WebsitePreferences] {
            Array(byDomain.values)
        }

        func clearPreferences(for domain: String) {
            byDomain.removeValue(forKey: domain)
        }

        func clearAllPreferences() {
            byDomain.removeAll()
        }
    }

    func testRegular_defaultsAllowAutofillAndSaving() {
        let prefs = InMemoryWebsitePreferencesStore()
        let engine = FormFillPolicyEngine(
            defaults: .init(allowAutofill: { true }, allowPasswordSaving: { true }),
            websitePreferencesStore: prefs
        )

        let policy = engine.effectivePolicy(siteKey: SiteKey(host: "example.com"), profile: .regular)
        XCTAssertTrue(policy.allowAutofill)
        XCTAssertTrue(policy.allowPasskeys) // JS enabled by default
        XCTAssertTrue(policy.allowPasswordSaving)
    }

    func testPrivate_disallowsPasswordSaving() {
        let prefs = InMemoryWebsitePreferencesStore()
        let engine = FormFillPolicyEngine(
            defaults: .init(allowAutofill: { true }, allowPasswordSaving: { true }),
            websitePreferencesStore: prefs
        )

        let policy = engine.effectivePolicy(siteKey: SiteKey(host: "example.com"), profile: .private)
        XCTAssertTrue(policy.allowAutofill)
        XCTAssertTrue(policy.allowPasskeys)
        XCTAssertFalse(policy.allowPasswordSaving)
    }

    func testPerSiteOverride_disablesAutofill() {
        let prefs = InMemoryWebsitePreferencesStore()
        var p = prefs.getPreferences(for: "example.com")
        p.autofillEnabled = false
        prefs.setPreferences(p, for: "example.com")

        let engine = FormFillPolicyEngine(
            defaults: .init(allowAutofill: { true }, allowPasswordSaving: { true }),
            websitePreferencesStore: prefs
        )

        let policy = engine.effectivePolicy(siteKey: SiteKey(host: "example.com"), profile: .regular)
        XCTAssertFalse(policy.allowAutofill)
        XCTAssertFalse(policy.allowPasskeys)
        XCTAssertFalse(policy.allowPasswordSaving)
    }

    func testJavaScriptDisabled_disablesPasskeysButNotPasswords() {
        let prefs = InMemoryWebsitePreferencesStore()
        var p = prefs.getPreferences(for: "example.com")
        p.javaScriptEnabled = false
        prefs.setPreferences(p, for: "example.com")

        let engine = FormFillPolicyEngine(
            defaults: .init(allowAutofill: { true }, allowPasswordSaving: { true }),
            websitePreferencesStore: prefs
        )

        let policy = engine.effectivePolicy(siteKey: SiteKey(host: "example.com"), profile: .regular)
        XCTAssertTrue(policy.allowAutofill)
        XCTAssertFalse(policy.allowPasskeys)
        XCTAssertTrue(policy.allowPasswordSaving)
    }

    func testContentBlockerException_doesNotDisableAutofill() {
        let prefs = InMemoryWebsitePreferencesStore()
        var p = prefs.getPreferences(for: "example.com")
        p.contentBlockerEnabled = false
        prefs.setPreferences(p, for: "example.com")

        let engine = FormFillPolicyEngine(
            defaults: .init(allowAutofill: { true }, allowPasswordSaving: { true }),
            websitePreferencesStore: prefs
        )

        let policy = engine.effectivePolicy(siteKey: SiteKey(host: "example.com"), profile: .regular)
        XCTAssertTrue(policy.allowAutofill)
        XCTAssertTrue(policy.allowPasswordSaving)
    }
}

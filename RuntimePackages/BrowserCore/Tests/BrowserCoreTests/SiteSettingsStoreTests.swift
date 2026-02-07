import XCTest
@testable import BrowserCore
import SafariLikeContracts

final class SiteSettingsStoreTests: XCTestCase {
    func testEffectiveDecisionFallsBackToGlobalDefault() async {
        let store = SiteSettingsStore(persistence: .memory)
        await store.setGlobalDefault(.allow, for: .camera)

        let key = SiteKey(host: "example.com")
        let decision = await store.effectiveDecision(for: key, type: .camera)
        XCTAssertEqual(decision, .allow)
    }

    func testPerSiteDecisionOverridesGlobalDefault() async {
        let store = SiteSettingsStore(persistence: .memory)
        await store.setGlobalDefault(.allow, for: .camera)

        let key = SiteKey(host: "example.com")
        await store.setDecision(.deny, for: key, type: .camera)

        let decision = await store.effectiveDecision(for: key, type: .camera)
        XCTAssertEqual(decision, .deny)
    }

    func testClearSiteRecordsRevertsToGlobalDefault() async {
        let store = SiteSettingsStore(persistence: .memory)
        await store.setGlobalDefault(.ask, for: .location)

        let key = SiteKey(host: "example.com")
        await store.setDecision(.allow, for: key, type: .location)
        let beforeClear = await store.effectiveDecision(for: key, type: .location)
        XCTAssertEqual(beforeClear, .allow)

        await store.clearSiteRecords(for: key)
        let afterClear = await store.effectiveDecision(for: key, type: .location)
        XCTAssertEqual(afterClear, .ask)
    }
}

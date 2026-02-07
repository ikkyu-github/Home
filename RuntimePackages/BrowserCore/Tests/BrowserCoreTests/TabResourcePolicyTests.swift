import XCTest
@testable import BrowserCore

#if canImport(SafariLikeCoreKit)
import SafariLikeCoreKit

final class TabResourcePolicyTests: XCTestCase {
    func testProtectedAndActiveTabsStayActiveUnderCriticalPressure() {
        let policy = SafariLikeCoreKit.TabResourcePolicy()
        let protectedID = UUID()
        let activeID = UUID()
        let otherID = UUID()

        let tabs: [TabResourcePolicy.TabDescriptor] = [
            .init(id: protectedID, isProtected: true, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: nil),
            .init(id: activeID, isProtected: false, isActive: true, isInSession: true, hasLiveWebView: true, lastActiveAt: nil),
            .init(id: otherID, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: nil)
        ]

        let decision = policy.decide(
            .init(
                memoryPressureLevel: .critical,
                visiblePanesCount: 1,
                activeTabCount: 2,
                tabs: tabs
            )
        )

        XCTAssertEqual(decision.actionsByTabID[protectedID], .stayActive)
        XCTAssertEqual(decision.actionsByTabID[activeID], .stayActive)
        XCTAssertEqual(decision.actionsByTabID[otherID], .evict)
    }

    func testNotInSessionLiveTabIsEvictedEvenWithoutPressure() {
        let policy = SafariLikeCoreKit.TabResourcePolicy()
        let zombieID = UUID()

        let tabs: [TabResourcePolicy.TabDescriptor] = [
            .init(id: zombieID, isProtected: false, isActive: false, isInSession: false, hasLiveWebView: true, lastActiveAt: nil)
        ]

        let decision = policy.decide(
            .init(
                memoryPressureLevel: .none,
                visiblePanesCount: 1,
                activeTabCount: 0,
                tabs: tabs
            )
        )

        XCTAssertEqual(decision.actionsByTabID[zombieID], .evict)
    }

    func testWarningPressureFreezesNonActiveTabsWhenNoWebViewBoundPlugins() {
        let policy = SafariLikeCoreKit.TabResourcePolicy()
        let activeID = UUID()
        let backgroundID = UUID()

        let tabs: [TabResourcePolicy.TabDescriptor] = [
            .init(id: activeID, isProtected: false, isActive: true, isInSession: true, hasLiveWebView: true, lastActiveAt: nil),
            .init(id: backgroundID, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: nil)
        ]

        let decision = policy.decide(
            .init(
                memoryPressureLevel: .warning,
                visiblePanesCount: 1,
                activeTabCount: 1,
                tabs: tabs,
                hasWebViewBoundPluginsEnabled: false
            )
        )

        XCTAssertEqual(decision.actionsByTabID[activeID], .stayActive)
        XCTAssertEqual(decision.actionsByTabID[backgroundID], .freeze)
    }

    func testWarningPressureKeepsEverythingActiveWhenWebViewBoundPluginsEnabled() {
        let policy = SafariLikeCoreKit.TabResourcePolicy()
        let a = UUID()
        let b = UUID()

        let tabs: [TabResourcePolicy.TabDescriptor] = [
            .init(id: a, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: nil),
            .init(id: b, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: false, lastActiveAt: nil)
        ]

        let decision = policy.decide(
            .init(
                memoryPressureLevel: .warning,
                visiblePanesCount: 1,
                activeTabCount: 0,
                tabs: tabs,
                hasWebViewBoundPluginsEnabled: true
            )
        )

        XCTAssertEqual(decision.actionsByTabID[a], .stayActive)
        XCTAssertEqual(decision.actionsByTabID[b], .stayActive)
    }

    func testTimeBasedDiscardEvictsInactiveTabs() {
        let policy = SafariLikeCoreKit.TabResourcePolicy()
        let oldID = UUID()
        let recentID = UUID()
        let now = Date()

        let tabs: [TabResourcePolicy.TabDescriptor] = [
            .init(id: oldID, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: now.addingTimeInterval(-3600)),
            .init(id: recentID, isProtected: false, isActive: false, isInSession: true, hasLiveWebView: true, lastActiveAt: now.addingTimeInterval(-30))
        ]

        let decision = policy.decide(
            .init(
                memoryPressureLevel: .none,
                visiblePanesCount: 1,
                activeTabCount: 0,
                tabs: tabs,
                now: now,
                discardInactiveAfter: 60
            )
        )

        XCTAssertEqual(decision.actionsByTabID[oldID], .evict)
        XCTAssertEqual(decision.actionsByTabID[recentID], .stayActive)
    }
}

#endif

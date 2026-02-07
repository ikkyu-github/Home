import XCTest
@testable import BrowserCore

final class TabDiscardPolicyTests: XCTestCase {

    func testVisibleTabsAreNeverDiscarded() {
        let now = Date(timeIntervalSince1970: 1_000)
        let visibleID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let hiddenID = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!

        let policy = TabDiscardPolicy(config: .default)
        let input = TabDiscardPolicy.Input(
            trigger: .memoryWarning(.critical),
            now: now,
            tabs: [
                .init(
                    tabID: visibleID,
                    lastActiveAt: now.addingTimeInterval(-10_000),
                    isVisible: true,
                    isPinned: false,
                    isUserLocked: false,
                    hasUnsavedForm: false,
                    isPlayingMedia: false,
                    memoryCostEstimate: 200,
                    currentLevel: .keepAttached
                ),
                .init(
                    tabID: hiddenID,
                    lastActiveAt: now.addingTimeInterval(-10_000),
                    isVisible: false,
                    isPinned: false,
                    isUserLocked: false,
                    hasUnsavedForm: false,
                    isPlayingMedia: false,
                    memoryCostEstimate: 200,
                    currentLevel: .keepAttached
                )
            ]
        )

        let decision = policy.decide(input)
        XCTAssertNil(decision.targetLevelByTabID[visibleID])
        XCTAssertNotNil(decision.targetLevelByTabID[hiddenID])
    }

    func testActionCapAndDeterministicTieBreak() {
        let now = Date(timeIntervalSince1970: 1_000)
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        var config = TabDiscardConfig.default
        config.maxActionsPerApply = 1

        let policy = TabDiscardPolicy(config: config)
        let input = TabDiscardPolicy.Input(
            trigger: .memoryWarning(.warning),
            now: now,
            tabs: [
                .init(
                    tabID: b,
                    lastActiveAt: now.addingTimeInterval(-10_000),
                    isVisible: false,
                    isPinned: false,
                    isUserLocked: false,
                    hasUnsavedForm: false,
                    isPlayingMedia: false,
                    memoryCostEstimate: 100,
                    currentLevel: .keepAttached
                ),
                .init(
                    tabID: a,
                    lastActiveAt: now.addingTimeInterval(-10_000),
                    isVisible: false,
                    isPinned: false,
                    isUserLocked: false,
                    hasUnsavedForm: false,
                    isPlayingMedia: false,
                    memoryCostEstimate: 100,
                    currentLevel: .keepAttached
                )
            ]
        )

        let decision = policy.decide(input)
        XCTAssertEqual(decision.orderedTabIDs, [a])
        XCTAssertEqual(decision.targetLevelByTabID[a], .detachKeepSnapshot)
        XCTAssertEqual(decision.targetLevelByTabID.count, 1)
    }

    func testInactiveSweepRespectsThreshold() {
        let now = Date(timeIntervalSince1970: 1_000)
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!

        var config = TabDiscardConfig.default
        config.tabInactiveLongThreshold = 600
        config.maxActionsPerApply = 5

        let policy = TabDiscardPolicy(config: config)
        let input = TabDiscardPolicy.Input(
            trigger: .tabInactiveSweep,
            now: now,
            tabs: [
                .init(
                    tabID: id,
                    lastActiveAt: now.addingTimeInterval(-100),
                    isVisible: false,
                    isPinned: false,
                    isUserLocked: false,
                    hasUnsavedForm: false,
                    isPlayingMedia: false,
                    memoryCostEstimate: 100,
                    currentLevel: .keepAttached
                )
            ]
        )

        let decision = policy.decide(input)
        XCTAssertTrue(decision.targetLevelByTabID.isEmpty)
        XCTAssertTrue(decision.orderedTabIDs.isEmpty)
    }
}

import XCTest
@testable import SafariLikeKit

@MainActor
final class SnapshotServiceTests: XCTestCase {
    func testSnapshotService_budgetEvictsLRU() {
        let budget = SnapshotService.Budget(maxSnapshots: 2, maxTotalCostBytes: 10, maxConcurrentCaptures: 1)
        let service = SnapshotService(budget: budget)

        let a = UUID()
        let b = UUID()
        let c = UUID()

        service.storeSnapshot(tabID: a, data: Data(repeating: 0xA, count: 6))
        service.storeSnapshot(tabID: b, data: Data(repeating: 0xB, count: 6))

        // Total bytes would be 12 > 10, so the LRU (A) must be evicted.
        XCTAssertNil(service.snapshot(for: a))
        XCTAssertNotNil(service.snapshot(for: b))

        service.storeSnapshot(tabID: c, data: Data(repeating: 0xC, count: 2))
        XCTAssertNotNil(service.snapshot(for: b))
        XCTAssertNotNil(service.snapshot(for: c))
    }

    func testTabManager_shutdownClearsSnapshots() async {
        let (_, manager) = SceneFactory.makeKitScene(sceneIDRaw: "scene-snapshots", windowID: "w-snapshots")

        let tabID = manager.newTab(inBackground: true)
        await Task.yield()

        manager.snapshotService.storeSnapshot(tabID: tabID, data: Data(repeating: 0xD, count: 16))
        XCTAssertNotNil(manager.snapshotDataForTabIfAvailable(tabID))
        XCTAssertNotNil(manager.snapshotService.snapshot(for: tabID))

        await manager.shutdown()

        XCTAssertNil(manager.snapshotDataForTabIfAvailable(tabID))
        XCTAssertNil(manager.snapshotService.snapshot(for: tabID))
    }
}

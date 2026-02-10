import XCTest
@testable import SafariLikeKit

@MainActor
final class TabManagerRegressionTests: XCTestCase {
    private func makeSceneAndManager() -> (scene: SceneRuntimeContext, manager: TabManager) {
        SceneFactory.makeKitScene(sceneIDRaw: "test.scene", windowID: "test.window")
    }

    func testNewTabSelectsNewTab() async {
        let (scene, manager) = makeSceneAndManager()
        let newTabID = manager.newTab(inBackground: false)
        XCTAssertEqual(manager.currentSessionStore.selectedTabID, newTabID)
        XCTAssertEqual(manager.activeTabID, newTabID)

        scene.shutdownAndReleaseWebViews()
        await manager.shutdown()
    }

    func testCloseSelectedTabFallsBackToFirstTab() async {
        let (scene, manager) = makeSceneAndManager()
        let tab1 = manager.newTab(inBackground: false)
        let tab2 = manager.newTab(inBackground: false)
        XCTAssertEqual(manager.currentSessionStore.selectedTabID, tab2)

        await manager.closeTabAsync(tab2)
        XCTAssertEqual(manager.currentSessionStore.selectedTabID, tab1)

        scene.shutdownAndReleaseWebViews()
        await manager.shutdown()
    }

    func testRapidTabSwitchingKeepsStateConsistent() async {
        let (scene, manager) = makeSceneAndManager()
        let tabIDs = (0..<5).map { _ in manager.newTab(inBackground: false) }
        for id in tabIDs.reversed() {
            manager.selectTab(id)
        }
        XCTAssertEqual(manager.currentSessionStore.selectedTabID, tabIDs.first)

        scene.shutdownAndReleaseWebViews()
        await manager.shutdown()
    }
}

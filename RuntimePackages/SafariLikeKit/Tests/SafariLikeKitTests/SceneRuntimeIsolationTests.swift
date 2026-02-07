import XCTest
@testable import SafariLikeKit

import BrowserCore
import SafariLikeCoreKit
import WebKit

@MainActor
final class SceneRuntimeIsolationTests: XCTestCase {
    func testSceneRuntimeContext_isolatedPerScene_andShutdownDoesNotCrossAffect() async {
        let (sceneA, managerA) = SceneFactory.makeKitScene(sceneIDRaw: "scene-A", windowID: "w-A")
        let (sceneB, managerB) = SceneFactory.makeKitScene(sceneIDRaw: "scene-B", windowID: "w-B")

        XCTAssertNotEqual(sceneA.windowID, sceneB.windowID)
        XCTAssertFalse(sceneA.tabRegistry === sceneB.tabRegistry)
        XCTAssertFalse(sceneA.privateTabRegistry === sceneB.privateTabRegistry)
        XCTAssertFalse(sceneA.webContextManager === sceneB.webContextManager)
        XCTAssertNotEqual(sceneA.webViewPool.poolID, sceneB.webViewPool.poolID)

        // Attachment coordinator must be scene-scoped.
        _ = sceneA.attachmentCoordinator
        _ = sceneB.attachmentCoordinator
        XCTAssertFalse(sceneA.attachmentCoordinator === sceneB.attachmentCoordinator)
        XCTAssertFalse(sceneA.watchdogController === sceneB.watchdogController)
        XCTAssertFalse(sceneA.uiState === sceneB.uiState)

        // TabManager should be wired to its scene runtime context (no process-global lookup).
        XCTAssertTrue(managerA.runtimeContextIfAvailable === sceneA)
        XCTAssertTrue(managerB.runtimeContextIfAvailable === sceneB)

        // Prove no cross-scene registry mutation during shutdown.
        let tabA = UUID()
        let tabB = UUID()
        _ = await sceneA.tabRegistry.store(for: tabA, role: .primary)
        _ = await sceneB.tabRegistry.store(for: tabB, role: .primary)
        XCTAssertNotNil(sceneA.tabRegistry.existingStore(for: tabA))
        XCTAssertNotNil(sceneB.tabRegistry.existingStore(for: tabB))

        sceneA.shutdownAndReleaseWebViews()

        // shutdownAndReleaseWebViews() runs registry.shutdown() in a task; poll briefly.
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if sceneA.tabRegistry.existingStore(for: tabA) == nil { break }
            await Task.yield()
        }

        XCTAssertNil(sceneA.tabRegistry.existingStore(for: tabA))
        XCTAssertNotNil(sceneB.tabRegistry.existingStore(for: tabB))
    }

    func testWebViewTransitionTokens_staleTokensDoNotValidate() {
        let (_, manager) = SceneFactory.makeKitScene(sceneIDRaw: "scene-tokens", windowID: "w-tokens")
        let tabID = UUID()

        let t1 = manager.beginWebViewTransition(reason: "test", tabID: tabID)
        XCTAssertTrue(manager.isCurrentWebViewTransition(tabID: tabID, token: t1))

        let t2 = manager.beginWebViewTransition(reason: "test", tabID: tabID)
        XCTAssertFalse(manager.isCurrentWebViewTransition(tabID: tabID, token: t1))
        XCTAssertTrue(manager.isCurrentWebViewTransition(tabID: tabID, token: t2))
    }
}

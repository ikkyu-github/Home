import XCTest
@testable import SafariLikeKit

import SafariLikeCoreKit

@MainActor
final class SceneMultiIsolationAndLeakTests: XCTestCase {

    func testScenesDoNotShareServices() async {
        let (sceneA, managerA) = SceneFactory.makeKitScene(sceneIDRaw: "scene-A", windowID: "w-A")
        let (sceneB, managerB) = SceneFactory.makeKitScene(sceneIDRaw: "scene-B", windowID: "w-B")

        XCTAssertFalse(sceneA === sceneB)
        XCTAssertNotEqual(sceneA.windowID, sceneB.windowID)
        XCTAssertNotEqual(sceneA.sceneID.raw, sceneB.sceneID.raw)

        XCTAssertFalse(sceneA.core === sceneB.core)
        XCTAssertFalse(sceneA.tabRegistry === sceneB.tabRegistry)
        XCTAssertFalse(sceneA.privateTabRegistry === sceneB.privateTabRegistry)
        XCTAssertFalse(sceneA.webViewPool === sceneB.webViewPool)
        XCTAssertFalse(sceneA.privateWebViewPool === sceneB.privateWebViewPool)
        XCTAssertFalse(sceneA.webContextManager === sceneB.webContextManager)
        XCTAssertFalse(sceneA.webContextRouter === sceneB.webContextRouter)

        _ = sceneA.attachmentCoordinator
        _ = sceneB.attachmentCoordinator
        XCTAssertFalse(sceneA.attachmentCoordinator === sceneB.attachmentCoordinator)

        sceneA.shutdownAndReleaseWebViews()
        await managerA.shutdown()
        sceneB.shutdownAndReleaseWebViews()
        await managerB.shutdown()
    }

    func testTabsAndAssignmentsAreIsolated() async throws {
        let (sceneA, managerA) = SceneFactory.makeKitScene(sceneIDRaw: "scene-A", windowID: "w-A")
        let (sceneB, managerB) = SceneFactory.makeKitScene(sceneIDRaw: "scene-B", windowID: "w-B")

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-000000001001")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-000000001002")!

        let storeA = await sceneA.tabRegistry.activatedStore(for: tabA, role: .primary)
        XCTAssertEqual(sceneA.tabRegistry.activeWebViewsCount, 1)
        XCTAssertEqual(sceneB.tabRegistry.activeWebViewsCount, 0)

        let storeB = await sceneB.tabRegistry.activatedStore(for: tabB, role: .primary)
        XCTAssertEqual(sceneA.tabRegistry.activeWebViewsCount, 1)
        XCTAssertEqual(sceneB.tabRegistry.activeWebViewsCount, 1)

        let webViewA = try XCTUnwrap(storeA.webViewHandle?.webView)
        let webViewB = try XCTUnwrap(storeB.webViewHandle?.webView)

        XCTAssertEqual(webViewA.safariLikeOwningWebViewPoolID, sceneA.webViewPool.poolID)
        XCTAssertEqual(webViewB.safariLikeOwningWebViewPoolID, sceneB.webViewPool.poolID)
        XCTAssertNotEqual(webViewA.safariLikeOwningWebViewPoolID, webViewB.safariLikeOwningWebViewPoolID)

        let ctxA = try XCTUnwrap(storeA.webContext)
        let ctxB = try XCTUnwrap(storeB.webContext)
        XCTAssertFalse(ctxA === ctxB)

        XCTAssertTrue(sceneA.webViewPool.liveTabIDsSnapshot.contains(tabA))
        XCTAssertFalse(sceneA.webViewPool.liveTabIDsSnapshot.contains(tabB))
        XCTAssertTrue(sceneB.webViewPool.liveTabIDsSnapshot.contains(tabB))
        XCTAssertFalse(sceneB.webViewPool.liveTabIDsSnapshot.contains(tabA))

        sceneA.shutdownAndReleaseWebViews()
        await managerA.shutdown()
        sceneB.shutdownAndReleaseWebViews()
        await managerB.shutdown()
    }

    func testTeardownReleasesSceneOwnedObjects() async throws {
        let sentinel = LeakSentinel()

        var scene: SafariLikeKit.SceneRuntimeContext?
        var manager: TabManager?
        do {
            let built = SceneFactory.makeKitScene(sceneIDRaw: "scene-leak", windowID: "w-leak")
            scene = built.scene
            manager = built.manager
        }

        // Force-create the attachment coordinator so we can verify it deallocates.
        _ = scene?.attachmentCoordinator

        var core: SafariLikeCoreKit.SceneRuntimeContext? = scene?.core
        var registry: SafariLikeCoreKit.TabRegistry? = scene?.tabRegistry
        var privateRegistry: SafariLikeCoreKit.TabRegistry? = scene?.privateTabRegistry
        var pool: WebViewPool? = scene?.webViewPool
        var webContextManager: WebContextManager? = scene?.webContextManager

        let tabID = UUID(uuidString: "00000000-0000-0000-0000-000000001101")!
        var store: SafariLikeCoreKit.TabWebStore? = await registry?.activatedStore(for: tabID, role: .primary)
        var webContext: SafariLikeCoreKit.WebContext? = store?.webContext

        if let scene {
            sentinel.track(scene, note: "Kit.SceneRuntimeContext")
            sentinel.track(scene.attachmentCoordinator, note: "AttachmentCoordinator")
        }
        if let core { sentinel.track(core, note: "CoreKit.SceneRuntimeContext") }
        if let registry { sentinel.track(registry, note: "TabRegistry") }
        if let privateRegistry { sentinel.track(privateRegistry, note: "PrivateTabRegistry") }
        if let pool { sentinel.track(pool, note: "WebViewPool") }
        if let webContextManager { sentinel.track(webContextManager, note: "WebContextManager") }
        if let webContext { sentinel.track(webContext, note: "WebContext") }

        // Teardown.
        scene?.shutdownAndReleaseWebViews()
        if let registry { await registry.shutdown() }
        if let privateRegistry { await privateRegistry.shutdown() }
        if let windowID = scene?.windowID {
            webContextManager?.tearDownWindow(windowID: windowID)
        }

        if let manager { await manager.shutdown() }

        // Drop all strong refs (including TabManager, which owns registries/pools).
        store = nil
        webContext = nil

        core = nil
        registry = nil
        privateRegistry = nil
        pool = nil
        webContextManager = nil

        manager = nil
        scene = nil

        await sentinel.assertDeallocatedEventually(timeout: 1.0)
    }
}

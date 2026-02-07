import XCTest
@testable import SafariLikeCoreKit

import BrowserCore

@MainActor
final class SceneMultiIsolationTests: XCTestCase {

    func testScenesDoNotShareServices() {
        let sceneA = SceneFactory.makeCoreScene(sceneID: "scene-A", windowID: "w-A")
        let sceneB = SceneFactory.makeCoreScene(sceneID: "scene-B", windowID: "w-B")

        XCTAssertFalse(sceneA === sceneB)
        XCTAssertNotEqual(sceneA.windowID, sceneB.windowID)
        XCTAssertNotEqual(sceneA.sceneIdentifier, sceneB.sceneIdentifier)

        XCTAssertFalse(sceneA.tabRegistry === sceneB.tabRegistry)
        XCTAssertFalse(sceneA.privateTabRegistry === sceneB.privateTabRegistry)
        XCTAssertFalse(sceneA.webViewPool === sceneB.webViewPool)
        XCTAssertFalse(sceneA.privateWebViewPool === sceneB.privateWebViewPool)
        XCTAssertFalse(sceneA.webContextManager === sceneB.webContextManager)
        XCTAssertFalse(sceneA.webContextRouter === sceneB.webContextRouter)

        XCTAssertNotEqual(sceneA.webViewPool.poolID, sceneB.webViewPool.poolID)
        XCTAssertNotEqual(sceneA.privateWebViewPool.poolID, sceneB.privateWebViewPool.poolID)
    }

    func testTabsAndAssignmentsAreIsolated() async throws {
        let sceneA = SceneFactory.makeCoreScene(sceneID: "scene-A", windowID: "w-A")
        let sceneB = SceneFactory.makeCoreScene(sceneID: "scene-B", windowID: "w-B")

        let tabA1 = UUID(uuidString: "00000000-0000-0000-0000-00000000D001")!
        let tabA2 = UUID(uuidString: "00000000-0000-0000-0000-00000000D002")!
        let tabB1 = UUID(uuidString: "00000000-0000-0000-0000-00000000E001")!

        _ = await sceneA.tabRegistry.store(for: tabA1, role: .primary)
        _ = await sceneA.tabRegistry.store(for: tabA2, role: .primary)
        XCTAssertEqual(sceneA.tabRegistry.aliveTabIDs.count, 2)
        XCTAssertEqual(sceneB.tabRegistry.aliveTabIDs.count, 0)

        let storeA1 = await sceneA.tabRegistry.activatedStore(for: tabA1, role: .primary)
        XCTAssertEqual(sceneA.tabRegistry.activeWebViewsCount, 1)
        XCTAssertEqual(sceneB.tabRegistry.activeWebViewsCount, 0)

        let storeB1 = await sceneB.tabRegistry.activatedStore(for: tabB1, role: .primary)
        XCTAssertEqual(sceneA.tabRegistry.activeWebViewsCount, 1)
        XCTAssertEqual(sceneB.tabRegistry.activeWebViewsCount, 1)

        XCTAssertLessThanOrEqual(sceneA.webViewPool.liveWebViewCount, sceneA.webViewPool.maxLiveWebViews)
        XCTAssertLessThanOrEqual(sceneB.webViewPool.liveWebViewCount, sceneB.webViewPool.maxLiveWebViews)

        XCTAssertTrue(sceneA.webViewPool.liveTabIDsSnapshot.contains(tabA1))
        XCTAssertFalse(sceneA.webViewPool.liveTabIDsSnapshot.contains(tabB1))
        XCTAssertTrue(sceneB.webViewPool.liveTabIDsSnapshot.contains(tabB1))
        XCTAssertFalse(sceneB.webViewPool.liveTabIDsSnapshot.contains(tabA1))

        let webViewA1 = try XCTUnwrap(storeA1.webViewHandle?.webView)
        let webViewB1 = try XCTUnwrap(storeB1.webViewHandle?.webView)

        XCTAssertEqual(webViewA1.safariLikeOwningWebViewPoolID, sceneA.webViewPool.poolID)
        XCTAssertNotEqual(webViewA1.safariLikeOwningWebViewPoolID, sceneB.webViewPool.poolID)

        XCTAssertEqual(webViewB1.safariLikeOwningWebViewPoolID, sceneB.webViewPool.poolID)
        XCTAssertNotEqual(webViewB1.safariLikeOwningWebViewPoolID, sceneA.webViewPool.poolID)

        let contextA1 = try XCTUnwrap(storeA1.webContext)
        let contextB1 = try XCTUnwrap(storeB1.webContext)
        XCTAssertFalse(contextA1 === contextB1)
    }

    func testTeardownReleasesSceneOwnedObjects() async throws {
        let sentinel = LeakSentinel()

        var scene: SafariLikeCoreKit.SceneRuntimeContext? = SceneFactory.makeCoreScene(sceneID: "scene-leak", windowID: "w-leak")
        var registry: SafariLikeCoreKit.TabRegistry? = scene?.tabRegistry
        var privateRegistry: SafariLikeCoreKit.TabRegistry? = scene?.privateTabRegistry
        var pool: WebViewPool? = scene?.webViewPool
        var manager: WebContextManager? = scene?.webContextManager
        var router: WebContextRouter? = scene?.webContextRouter

        let tabID = UUID(uuidString: "00000000-0000-0000-0000-00000000F001")!
        var store: TabWebStore? = await registry?.activatedStore(for: tabID, role: .primary)
        var webContext: WebContext? = store?.webContext

        if let scene { sentinel.track(scene, note: "SceneRuntimeContext") }
        if let registry { sentinel.track(registry, note: "TabRegistry") }
        if let privateRegistry { sentinel.track(privateRegistry, note: "PrivateTabRegistry") }
        if let pool { sentinel.track(pool, note: "WebViewPool") }
        if let manager { sentinel.track(manager, note: "WebContextManager") }
        if let router { sentinel.track(router, note: "WebContextRouter") }
        if let store { sentinel.track(store, note: "TabWebStore") }
        if let webContext { sentinel.track(webContext, note: "WebContext") }

        // Teardown (deterministic): trigger the scene teardown, then await registry shutdown.
        scene?.shutdownAndReleaseWebViews()
        if let registry { await registry.shutdown() }
        if let privateRegistry { await privateRegistry.shutdown() }
        if let windowID = scene?.windowID {
            scene?.webContextManager.tearDownWindow(windowID: windowID)
        }

        // Drop all strong refs.
        store = nil
        webContext = nil

        scene = nil
        registry = nil
        privateRegistry = nil
        pool = nil
        manager = nil
        router = nil

        await sentinel.assertDeallocatedEventually(timeout: 1.0)
    }
}

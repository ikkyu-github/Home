import XCTest
@testable import SafariLikeCoreKit
import WebKit
import BrowserCore

@MainActor
final class TabRegistryBudgetTests: XCTestCase {

    private func makeServices() -> (manager: WebContextManager, router: WebContextRouter) {
        let store = SiteHeuristicsStore()
        return (manager: WebContextManager(), router: WebContextRouter(store: store))
    }

    private func makePool(label: String) -> WebViewPool {
        WebViewPool(
            label: label,
            maxLiveWebViews: 2,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
    }

    func testActivateAThenBThenCDeactivatesLRUAndKeepsActiveCountAtTwo() async throws {
        let registry = TabRegistry(
            windowID: "test",
            defaultHomeURLString: "about:blank",
            browsingProfile: .regular,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 6
        )
        let services = makeServices()
        registry.setWebContextServices(manager: services.manager, router: services.router)
        let pool = makePool(label: "tests.regular")
        registry.registerWebViewPool(pool, forPane: "primary")
        defer {
            Task { @MainActor in
                await registry.shutdown()
            }
        }

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
        let tabC = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!

        _ = await registry.activatedStore(for: tabA, role: TabWebStore.Role.primary)
        XCTAssertEqual(registry.activeWebViewsCount, 1)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, pool.maxLiveWebViews)

        _ = await registry.activatedStore(for: tabB, role: TabWebStore.Role.primary)
        XCTAssertEqual(registry.activeWebViewsCount, 2)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, pool.maxLiveWebViews)

        // At this point, A is LRU (activated first) and should be evicted when activating C.
        _ = await registry.activatedStore(for: tabC, role: TabWebStore.Role.primary)
        XCTAssertEqual(registry.activeWebViewsCount, 2)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, pool.maxLiveWebViews)

        let storeA: TabWebStore = try XCTUnwrap(registry.existingStore(for: tabA))
        let storeB: TabWebStore = try XCTUnwrap(registry.existingStore(for: tabB))
        let storeC: TabWebStore = try XCTUnwrap(registry.existingStore(for: tabC))

        XCTAssertNil(storeA.webViewHandle, "LRU tab A should have been deactivated")
        XCTAssertNotNil(storeB.webViewHandle)
        XCTAssertNotNil(storeC.webViewHandle)

        let activeIDs = registry.activeTabIDsLRUSnapshot()
        XCTAssertTrue(activeIDs.contains(tabB))
        XCTAssertTrue(activeIDs.contains(tabC))
        XCTAssertFalse(activeIDs.contains(tabA))
    }

    func testReactivatingEvictedTabRelessesAndStaysUnderLiveBudget() async throws {
        let registry = TabRegistry(
            windowID: "test",
            defaultHomeURLString: "about:blank",
            browsingProfile: .regular,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 20,
            maxConcurrentActiveWebViewsOverride: 2
        )
        let services = makeServices()
        registry.setWebContextServices(manager: services.manager, router: services.router)
        let pool = makePool(label: "tests.regular")
        pool.maxLiveWebViews = 2
        registry.registerWebViewPool(pool, forPane: "primary")
        defer {
            Task { @MainActor in
                await registry.shutdown()
            }
        }

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
        let tabC = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!

        _ = await registry.activatedStore(for: tabA, role: .primary)
        _ = await registry.activatedStore(for: tabB, role: .primary)
        XCTAssertEqual(registry.activeWebViewsCount, 2)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, 2)

        // Activating C should rotate active views (A becomes inactive).
        _ = await registry.activatedStore(for: tabC, role: .primary)
        XCTAssertEqual(registry.activeWebViewsCount, 2)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, 2)

        // Reactivating A should keep us under budget as well.
        _ = await registry.activatedStore(for: tabA, role: .primary)
        XCTAssertEqual(registry.activeWebViewsCount, 2)
        XCTAssertLessThanOrEqual(pool.liveWebViewCount, 2)
    }

    func testSceneShutdownReleasesAllWebViews() async {
        let registry = TabRegistry(
            windowID: "test",
            defaultHomeURLString: "about:blank",
            browsingProfile: .regular,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 20,
            maxConcurrentActiveWebViewsOverride: 2
        )
        let privateRegistry = TabRegistry(
            windowID: "test",
            defaultHomeURLString: "about:blank",
            browsingProfile: .private,
            debugLogEnabled: false,
            maxAliveWebViewsOverride: 20,
            maxConcurrentActiveWebViewsOverride: 2
        )

        let primaryPane = PaneID.primary.rawValue
        let secondaryPane = PaneID.secondary.rawValue

        let regularPool = WebViewPool(
            label: "tests.scene.regular",
            maxLiveWebViews: 2,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .regular)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
        registry.registerWebViewPool(regularPool, forPane: primaryPane)
        registry.registerWebViewPool(regularPool, forPane: secondaryPane)

        let privatePool = WebViewPool(
            label: "tests.scene.private",
            maxLiveWebViews: 2,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .private)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
        privateRegistry.registerWebViewPool(privatePool, forPane: primaryPane)
        privateRegistry.registerWebViewPool(privatePool, forPane: secondaryPane)

        let store = SiteHeuristicsStore()
        let core = SceneRuntimeContext(
            sceneIdentifier: "scene-tests",
            windowID: "w-tests",
            tabRegistry: registry,
            privateTabRegistry: privateRegistry,
            siteHeuristicsStore: store,
            budget: WebViewBudget(
                regular: .init(maxLiveWebViews: 2, maxConcurrentActiveWebViews: 2),
                privateProfile: .init(maxLiveWebViews: 2, maxConcurrentActiveWebViews: 2)
            )
        )

        let tabA = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
        let tabB = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!

        _ = await registry.activatedStore(for: tabA, role: .primary)
        _ = await registry.activatedStore(for: tabB, role: .primary)
        XCTAssertGreaterThan(core.webViewPool.liveWebViewCount, 0)

        core.shutdownAndReleaseWebViews()

        // shutdownAndReleaseWebViews() kicks async shutdown; poll briefly.
        let deadline = Date().addingTimeInterval(1.0)
        while Date() < deadline {
            if core.webViewPool.liveWebViewCount == 0, core.privateWebViewPool.liveWebViewCount == 0 { break }
            await Task.yield()
        }

        XCTAssertEqual(core.webViewPool.liveWebViewCount, 0)
        XCTAssertEqual(core.privateWebViewPool.liveWebViewCount, 0)
    }
}

import XCTest
@testable import SafariLikeCoreKit
import BrowserCore
import WebKit

/// Lifecycle tests for TabWebStore.
///
/// These tests focus on construction, bind/invalidate/deinit behavior,
/// and repeated creation/teardown. They intentionally do not mock
/// network – only basic lifecycle interactions are exercised.
@MainActor
final class TabWebStoreLifecycleTests: XCTestCase {

    private let windowID = "test-window"
    private let paneID = "primary"

    private func makeServices() -> (manager: WebContextManager, router: WebContextRouter) {
        let store = SiteHeuristicsStore()
        return (WebContextManager(), WebContextRouter(store: store))
    }

    private func makeStore(
        tabID: UUID = UUID(),
        role: TabWebStore.Role = .primary,
        browsingProfile: BrowsingProfile = .private
    ) -> TabWebStore {
        let configFactory = WebViewConfigurationFactory()
        let configuration = configFactory.makeConfiguration(profile: browsingProfile)
        let services = makeServices()
        return TabWebStore(
            tabID: tabID,
            windowID: windowID,
            paneID: paneID,
            role: role,
            configuration: configuration,
            defaultHomeURLString: "about:blank",
            searchEngineURL: DefaultURLs.SearchEngine.googleQuery,
            browsingProfile: browsingProfile,
            configFactory: configFactory,
            webContextManager: services.manager,
            webContextRouter: services.router
        )
    }

    private func makePrivatePool() -> WebViewPool {
        WebViewPool(
            label: "tests.private",
            maxLiveWebViews: 2,
            makeWebView: {
                let config = EngineController.shared.makeWebViewConfiguration(profile: .private)
                return WebViewPool.makeWebView(configuration: config)
            }
        )
    }

    func testBindInvalidateDeinitDoesNotCrash() async {
        // GIVEN a TabWebStore that binds to a WKWebView
        var store: TabWebStore? = makeStore()

        // WHEN we explicitly invalidate and then release it
        if let store {
            await store.invalidate()
        }
        store = nil

        // THEN deinit must not crash – reaching here is success.
        XCTAssertTrue(true)
    }

    func testNoCallbacksAfterInvalidateAndDeinit() async {
        // GIVEN a TabWebStore with callbacks attached
        let expectationFinished = expectation(description: "onPageDidFinish should not fire after invalidate+deinit")
        expectationFinished.isInverted = true

        var store: TabWebStore? = makeStore()

        store?.onPageDidFinish = { _, _ in
            expectationFinished.fulfill()
        }

        // WHEN we invalidate and release the store
        if let store {
            await store.invalidate()
        }
        store = nil

        // THEN no more callbacks should fire on the released instance.
        await fulfillment(of: [expectationFinished], timeout: 1.0)
    }

    func testCreateAndCloseTabsInLoop() async {
        // GIVEN a loop that creates and tears down TabWebStore instances
        let iterations = 10

        for _ in 0..<iterations {
            let store = makeStore()

            // Basic sanity: webView can be created and torn down repeatedly.
            await store.activate(using: makePrivatePool())
            XCTAssertNotNil(store.webViewHandle?.webView)

            // Explicitly invalidate before going out of scope
            await store.invalidate()
        }

        // THEN the loop should complete without crashes or leaks noticeable to XCTest.
        XCTAssertTrue(true)
    }

    func testActivateIsIdempotentDoesNotCreateNewWebView() async {
        // GIVEN a TabWebStore
        let store = makeStore()

        // WHEN activate() is called multiple times
        await store.activate(using: makePrivatePool())
        let firstWebView = store.webViewHandle?.webView
        XCTAssertNotNil(firstWebView)

        await store.activate(using: makePrivatePool())
        let secondWebView = store.webViewHandle?.webView
        XCTAssertNotNil(secondWebView)

        // THEN the web view must be reused (no duplicate creation)
        XCTAssertTrue(firstWebView === secondWebView)

        await store.invalidate()
    }

    func testTabWebStoreInvalidateDoesNotCrash() async {
        // GIVEN a TabWebStore that has been configured and used briefly
        let store = makeStore()

        await store.activate(using: makePrivatePool())

        // Exercise a few public APIs before invalidation
        store.load("https://example.com", force: false)
        store.loadSearch(query: "SafariLikeCoreKit")

        // WHEN we invalidate and then call various methods again
        await store.invalidate()

        // These calls must be safe no-ops and must not crash.
        store.load("https://apple.com", force: false)
        store.loadSearch(query: "after invalidate")
        store.setBypassSmartSplitOnce()
        store.performLoadResolvedURL("https://swift.org")

        // THEN simply reaching here without a crash is success.
        XCTAssertTrue(true)
    }

    func testObserverTokenRemovedOnInvalidate() async throws {
        #if os(macOS)
        throw XCTSkip("Unstable on macOS SwiftPM test runner (malloc abort).")
        #else
        // GIVEN a TabWebStore with a state observer attached
        let store = makeStore()

        let noCallbackAfterInvalidate = expectation(description: "observer should not be called after invalidate")
        noCallbackAfterInvalidate.isInverted = true

        var callbacksAfterInvalidate = 0

        _ = store.observeState { [weak store] (_ state: TabWebStoreState) in
            if store?.isInvalidated == true {
                callbacksAfterInvalidate += 1
                noCallbackAfterInvalidate.fulfill()
            }
        }

        // Trigger at least one state change before invalidation
        store.updatePageTitle("before invalidate")

        // WHEN we invalidate and then force internal state updates
        await store.invalidate()
        store.updatePageTitle("after invalidate")
        store.updateCurrentURL(URL(string: "https://example.com/after"))
        store.updateCanGoBack(true)
        store.updateCanGoForward(true)
        store.updateEstimatedProgress(0.5)
        store.updateIsLoading(true)

        // THEN no callbacks should be delivered after invalidate
        await fulfillment(of: [noCallbackAfterInvalidate], timeout: 0.5)
        XCTAssertEqual(callbacksAfterInvalidate, 0)
        #endif
    }

    func testProcessRecoveryBackoffWorks() async {
        // GIVEN a TabWebStore with an active URL and app marked as active
        let store = makeStore()
        store.isAppActiveClosure = { true }

        await store.activate(using: makePrivatePool())

        // Ensure webView has a URL so scheduleProcessRecoverIfNeeded passes guards.
        // Use about:blank to avoid network dependencies.
        guard let url = URL(string: "about:blank"), let webView = store.webViewHandle?.webView else {
            XCTFail("Expected about:blank to be a valid URL")
            return
        }
        webView.load(URLRequest(url: url))

        // CASE 1: No recent recovery (large gap) → attempts should not increase and delay is base.
        store.processRecoverAttempts = 0
        store.lastProcessRecoverAt = CFAbsoluteTimeGetCurrent() - 10.0
        store.scheduleProcessRecoverIfNeeded()
        XCTAssertEqual(store.processRecoverAttempts, 0)
        XCTAssertEqual(store.lastProcessRecoverDelayForTesting, 0.20, accuracy: 0.01)

        // CASE 2: Recent recovery (within 2s) → attempts increase and delay grows.
        store.processRecoverAttempts = 0
        store.lastProcessRecoverAt = CFAbsoluteTimeGetCurrent()
        store.scheduleProcessRecoverIfNeeded()
        XCTAssertEqual(store.processRecoverAttempts, 1)
        XCTAssertEqual(store.lastProcessRecoverDelayForTesting, 0.40, accuracy: 0.05)

        // CASE 3: Multiple rapid calls grow delay but clamp at 10 seconds maximum.
        store.processRecoverAttempts = 0
        store.lastProcessRecoverAt = CFAbsoluteTimeGetCurrent()
        for _ in 0..<8 {
            store.scheduleProcessRecoverIfNeeded()
            store.lastProcessRecoverAt = CFAbsoluteTimeGetCurrent()
        }
        XCTAssertLessThanOrEqual(store.lastProcessRecoverDelayForTesting, 10.0)
        XCTAssertGreaterThan(store.lastProcessRecoverDelayForTesting, 0.40)
    }

    func testScriptMessageHandlersRemoved() async {
        // GIVEN a TabWebStore whose WKWebView has user scripts and message handlers installed
        let store = makeStore()

        await store.activate(using: makePrivatePool())

        guard let webView = store.webViewHandle?.webView else {
            XCTFail("Expected webView to be created after activate()")
            return
        }
        let controller = webView.configuration.userContentController

        // Initial configuration should have at least one user script installed
        XCTAssertGreaterThan(controller.userScripts.count, 0)

        // WHEN we explicitly tear down the web view core
        store.invalidateWebViewCore()

        // THEN user scripts should be removed; reaching here without crash
        // also implies removeScriptMessageHandler calls were safe.
        XCTAssertEqual(controller.userScripts.count, 0)
    }
}

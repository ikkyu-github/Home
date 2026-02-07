import XCTest
import WebKit
@testable import SafariLikeCoreKit

final class WebViewPoolLeakTests: XCTestCase {
    func testOpenCloseTabDoesNotLeakWebView() {
        let pool = WebViewPool(label: "test", maxLiveWebViews: 2)
        let context = WebContext(configuration: WKWebViewConfiguration(), privacyMode: .regular)
        let tabID = UUID()
        let webView = pool.acquire(for: tabID, context: context)
        pool.release(tabID: tabID)
        XCTAssertEqual(pool.liveWebViewCount, 0)
    }

    func testMultipleOpenCloseTabsNoLeak() {
        let pool = WebViewPool(label: "test", maxLiveWebViews: 2)
        let contexts = (0..<5).map { _ in WebContext(configuration: WKWebViewConfiguration(), privacyMode: .regular) }
        let tabIDs = contexts.map { _ in UUID() }
        for (tabID, context) in zip(tabIDs, contexts) {
            _ = pool.acquire(for: tabID, context: context)
        }
        for tabID in tabIDs {
            pool.release(tabID: tabID)
        }
        XCTAssertEqual(pool.liveWebViewCount, 0)
    }

    func testPoolDoesNotHoldReleasedWebView() {
        let pool = WebViewPool(label: "test", maxLiveWebViews: 2)
        let context = WebContext(configuration: WKWebViewConfiguration(), privacyMode: .regular)
        let tabID = UUID()
        let webView = pool.acquire(for: tabID, context: context)
        pool.release(tabID: tabID)
        XCTAssertFalse(pool.liveTabIDsSnapshot.contains(tabID))
    }
}

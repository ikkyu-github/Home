import XCTest
import UIKit
import WebKit
@testable import SafariLikeKit
import SafariLikeCoreKit

@MainActor
final class ShareCoordinatorTests: XCTestCase {
    func testShareLinkPresentsURL() {
        let presenter = CapturingPresenter()
        let coordinator = ShareCoordinator(
            presenter: presenter,
            pdfGenerator: StubPDFGenerator(data: Data([0x25, 0x50, 0x44, 0x46])),
            tempStore: StubTempStore()
        )

        let context = StubShareContext(
            activeTabID: UUID(),
            url: URL(string: "https://example.com")!,
            title: "Example",
            webView: WebViewPool.makeWebView(configuration: WKWebViewConfiguration())
        )

        coordinator.shareCurrentPageLink(from: context)

        XCTAssertEqual(presenter.presentCallCount, 1)
        XCTAssertEqual((presenter.lastItems.first as? URL)?.absoluteString, "https://example.com")
    }

    func testSharePDFWritesTempAndDeletesOnCompletion() async {
        let presenter = CapturingPresenter()
        let tempStore = StubTempStore()
        let coordinator = ShareCoordinator(
            presenter: presenter,
            pdfGenerator: StubPDFGenerator(data: Data([0x01, 0x02, 0x03])),
            tempStore: tempStore
        )

        let context = StubShareContext(
            activeTabID: UUID(),
            url: URL(string: "https://example.com")!,
            title: "Example",
            webView: WebViewPool.makeWebView(configuration: WKWebViewConfiguration())
        )

        coordinator.shareCurrentPageAsPDF(from: context)

        // Allow the Task to run.
        await Task.yield()

        XCTAssertEqual(presenter.presentCallCount, 1)
        guard let url = presenter.lastItems.first as? URL else {
            XCTFail("Expected temp file URL")
            return
        }
        XCTAssertTrue(url.isFileURL)
        XCTAssertEqual(tempStore.writtenURLs.count, 1)

        // Simulate user finishing share sheet.
        presenter.lastCompletion?(true)
        XCTAssertEqual(tempStore.deletedURLs, [url])
    }
}

@MainActor
private final class CapturingPresenter: ShareActivityPresenting {
    private(set) var presentCallCount: Int = 0
    private(set) var lastItems: [Any] = []
    private(set) var lastAnchor: UIView?
    var lastCompletion: ((Bool) -> Void)?

    func present(activityItems: [Any], anchorView: UIView?, completion: @escaping (Bool) -> Void) {
        presentCallCount += 1
        lastItems = activityItems
        lastAnchor = anchorView
        lastCompletion = completion
    }
}

@MainActor
private struct StubPDFGenerator: WebViewPDFGenerating {
    let data: Data
    func createPDFData(from webView: WKWebView) async throws -> Data { data }
}

@MainActor
private final class StubTempStore: ShareTemporaryFileStoring {
    private(set) var writtenURLs: [URL] = []
    private(set) var deletedURLs: [URL] = []

    func writeTemporaryFile(data: Data, preferredFilename: String, fileExtension: String) throws -> URL {
        let url = URL(fileURLWithPath: "/tmp/test-\(UUID().uuidString).\(fileExtension)")
        writtenURLs.append(url)
        return url
    }

    func deleteTemporaryFile(at url: URL) {
        deletedURLs.append(url)
    }
}

@MainActor
private final class StubShareContext: ShareContextProviding {
    var activeTabID: UUID?
    var share_currentURL: URL?
    var share_pageTitle: String?
    var share_anchorWebView: WKWebView?

    init(activeTabID: UUID?, url: URL?, title: String?, webView: WKWebView?) {
        self.activeTabID = activeTabID
        self.share_currentURL = url
        self.share_pageTitle = title
        self.share_anchorWebView = webView
    }
}

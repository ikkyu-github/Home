import Foundation
import UIKit
import WebKit
import OSLog
import SafariLikeCoreKit

@MainActor
protocol ShareContextProviding: AnyObject {
    var activeTabID: UUID? { get }
    var share_currentURL: URL? { get }
    var share_pageTitle: String? { get }
    var share_anchorWebView: WKWebView? { get }
}

@MainActor
extension SplitBrowserViewModel: ShareContextProviding {
    var share_currentURL: URL? { activeStore?.state.currentURL }
    var share_pageTitle: String? { activeStore?.state.pageTitle }
    var share_anchorWebView: WKWebView? { activeStore?.webViewHandle?.webView }
}

@MainActor
protocol ShareActivityPresenting {
    func present(
        activityItems: [Any],
        anchorView: UIView?,
        completion: @escaping (_ completed: Bool) -> Void
    )
}

@MainActor
final class UIKitShareActivityPresenter: ShareActivityPresenting {
    func present(
        activityItems: [Any],
        anchorView: UIView?,
        completion: @escaping (_ completed: Bool) -> Void
    ) {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            completion(completed)
        }

        if let pop = controller.popoverPresentationController {
            let view = anchorView ?? UIApplication.shared.topMostViewController()?.view
            pop.sourceView = view
            if let view {
                pop.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1)
            } else {
                pop.sourceRect = .zero
            }
            pop.permittedArrowDirections = []
        }

        UIApplication.shared.topMostViewController()?.present(controller, animated: true)
    }
}

@MainActor
protocol WebViewPDFGenerating {
    func createPDFData(from webView: WKWebView) async throws -> Data
}

@MainActor
struct WKWebViewPDFGenerator: WebViewPDFGenerating {
    func createPDFData(from webView: WKWebView) async throws -> Data {
        if #available(iOS 14.0, *) {
            return try await withCheckedThrowingContinuation { continuation in
                let config = WKPDFConfiguration()
                webView.createPDF(configuration: config) { result in
                    continuation.resume(with: result)
                }
            }
        }
        throw NSError(domain: "ShareCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "PDF generation requires iOS 14+"])
    }
}

@MainActor
protocol ShareTemporaryFileStoring {
    func writeTemporaryFile(data: Data, preferredFilename: String, fileExtension: String) throws -> URL
    func deleteTemporaryFile(at url: URL)
}

@MainActor
final class DefaultShareTemporaryFileStore: ShareTemporaryFileStoring {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "ShareTemp")

    func writeTemporaryFile(data: Data, preferredFilename: String, fileExtension: String) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SafariLikeShare", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let stem = preferredFilename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\\\", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let safeStem = stem.isEmpty ? "Share" : String(stem.prefix(80))
        let filename = safeStem + "-" + UUID().uuidString + "." + fileExtension

        let url = dir.appendingPathComponent(filename, isDirectory: false)
        try data.write(to: url, options: [.atomic])
        return url
    }

    func deleteTemporaryFile(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            Self.logger.debug("Failed to delete temp share file: \(url.absoluteString, privacy: .public) error=\(String(describing: error), privacy: .public)")
        }
    }
}

@MainActor
final class ShareCoordinator {
    private static let logger = Logger(subsystem: "SafariLikeKit", category: "Share")

    private let presenter: ShareActivityPresenting
    private let pdfGenerator: WebViewPDFGenerating
    private let tempStore: ShareTemporaryFileStoring

    init(
        presenter: (any ShareActivityPresenting)? = nil,
        pdfGenerator: (any WebViewPDFGenerating)? = nil,
        tempStore: (any ShareTemporaryFileStoring)? = nil
    ) {
        self.presenter = presenter ?? UIKitShareActivityPresenter()
        self.pdfGenerator = pdfGenerator ?? WKWebViewPDFGenerator()
        self.tempStore = tempStore ?? DefaultShareTemporaryFileStore()
    }

    func shareCurrentPageLink(from context: any ShareContextProviding) {
        guard let url = context.share_currentURL else {
            Self.logger.debug("shareCurrentPageLink: currentURL nil")
            return
        }
        let anchor = context.share_anchorWebView
        Self.logger.debug("shareCurrentPageLink url=\(url.absoluteString, privacy: .public)")
        presenter.present(activityItems: [url], anchorView: anchor) { _ in }
    }

    func shareDownloadFile(_ fileURL: URL, anchorView: UIView?) {
        presenter.present(activityItems: [fileURL], anchorView: anchorView) { _ in }
    }

    func shareCurrentPageAsPDF(from context: any ShareContextProviding) {
        guard let webView = context.share_anchorWebView else {
            Self.logger.debug("shareCurrentPageAsPDF: webView nil")
            return
        }
        let tabIDAtTap = context.activeTabID
        let suggested = (context.share_pageTitle?.isEmpty == false ? context.share_pageTitle! : "Page")
        let anchor = webView

        Task { @MainActor in
            do {
                let pdfData = try await pdfGenerator.createPDFData(from: webView)
                let fileURL = try tempStore.writeTemporaryFile(data: pdfData, preferredFilename: suggested, fileExtension: "pdf")

                // State must be driven by active tab only: if user switched tabs during generation, abort.
                guard context.activeTabID == tabIDAtTap else {
                    tempStore.deleteTemporaryFile(at: fileURL)
                    Self.logger.debug("shareCurrentPageAsPDF: tab changed; aborting")
                    return
                }

                presenter.present(activityItems: [fileURL], anchorView: anchor) { [tempStore] _ in
                    tempStore.deleteTemporaryFile(at: fileURL)
                }
            } catch {
                Self.logger.error("shareCurrentPageAsPDF failed: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

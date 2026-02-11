import Foundation
import SafariLikeCoreKit
/// Abstraction for browser commands so UI/Views do not call stores or runtime directly.
@MainActor
protocol BrowserActions: AnyObject {
    func open(urlString: String)
    func reload()
    func goBack()
    func goForward()
    func stopLoading()
    func newTab()
    func closeActiveTab()
    func selectTab(id: UUID)
}

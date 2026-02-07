import Foundation
import SafariLikeCoreKit
@MainActor
final class TabService {
    func perform(_ action: BrowserAction, in viewModel: SplitBrowserViewModel) {
        switch action {
        case .newTab(let urlString, let inBackground):
            viewModel.openTab(urlString: urlString, inBackground: inBackground)
        case .closeTab(let id):
            viewModel.closeTab(id)
        case .selectTab(let id):
            viewModel.selectTab(id)
        case .moveTab(let from, let to):
            viewModel.moveTab(from: from, to: to)
        default:
            break
        }
    }
    func setSplitEnabled(_ enabled: Bool, in viewModel: SplitBrowserViewModel) {
        viewModel.toggleSplitView()
    }
}

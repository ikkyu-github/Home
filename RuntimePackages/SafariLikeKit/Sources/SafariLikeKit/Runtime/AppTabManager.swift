import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
final class AppTabManager: ObservableObject {
    // Strong references: AppTabManager is a session-scoped helper and
    // should share lifetime with its BrowserSceneSession owner.
    private let session: BrowserSceneSession
    private let viewModel: SplitBrowserViewModel
    init(session: BrowserSceneSession) {
        // Keep the session and its view model alive for as long as
        // this manager is used; this avoids unexpected deallocation.
        self.session = session
        self.viewModel = session.viewModel
    }
    // MARK: - Tabs
    @discardableResult
    func openNewTab(inGroup groupID: UUID? = nil) -> UUID {
        let id = session.viewModel.sessionStore.addTab()
        if let groupID { session.viewModel.sessionStore.addTabToGroup(tabID: id, groupID: groupID) }
        selectTab(id)
        return id
    }
    func selectTab(_ id: UUID) {
        viewModel.selectTab(id)
    }
    func closeTab(_ id: UUID) {
        viewModel.closeTab(id)
    }
    // MARK: - Split View (Safari iPad-style)
    var isSplitViewEnabled: Bool {
        viewModel.isSplitViewEnabled
    }
    func enableSplitView() {
        guard !viewModel.isSplitViewEnabled else { return }
        viewModel.toggleSplitView()
    }
    func disableSplitView() {
        guard viewModel.isSplitViewEnabled else { return }
        viewModel.toggleSplitView()
    }
    func selectLeftPane() {
        viewModel.selectLeftPane()
    }
    func selectRightPane() {
        viewModel.selectRightPane()
    }
}

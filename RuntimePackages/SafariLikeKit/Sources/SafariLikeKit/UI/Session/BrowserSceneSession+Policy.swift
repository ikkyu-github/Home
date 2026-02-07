import Foundation
import SafariLikeCoreKit
@MainActor
extension BrowserSceneSession {
    // MARK: - Internal Stores & Managers (for App integration)
    public var sessionStore: BrowserSessionStore {
        viewModel.sessionStore
    }
}

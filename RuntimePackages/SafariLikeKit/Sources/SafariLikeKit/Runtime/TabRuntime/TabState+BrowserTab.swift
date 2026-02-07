import Foundation
import SafariLikeCoreKit
extension TabState {
    /// Bridge persisted `BrowserTab` metadata into the Engine tab state model.
    init(browserTab: BrowserTab, isPrivate: Bool) {
        self.init(
            id: browserTab.id,
            url: URL(string: browserTab.urlString),
            title: browserTab.title,
            lastActiveAt: browserTab.lastVisitedAt,
            hasSnapshot: false,
            lastSnapshotAt: nil,
            snapshotData: nil,
            isPrivate: isPrivate,
            lifecycle: browserTab.lifecycleState,
            runtimeAttachment: .detached
        )
    }
}

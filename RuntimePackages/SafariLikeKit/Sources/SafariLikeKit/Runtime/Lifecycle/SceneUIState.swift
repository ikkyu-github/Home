import Foundation
import Combine
import SafariLikeCoreKit
/// Per-window UI state that should not be shared across scenes.
///
/// This intentionally holds only lightweight, UI-scoped flags.
@MainActor
public final class SceneUIState: ObservableObject {
    @Published public var isSidebarVisible: Bool
    @Published public var isRelatedPaneVisible: Bool
    public init(isSidebarVisible: Bool = false, isRelatedPaneVisible: Bool = false) {
        self.isSidebarVisible = isSidebarVisible
        self.isRelatedPaneVisible = isRelatedPaneVisible
    }
}

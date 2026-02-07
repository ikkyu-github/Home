import Foundation
import SafariLikeContracts
import SafariLikeUXKit

@MainActor
extension BrowserChromeState {
    /// UI-safe chrome view state snapshot (contract type).
    ///
    /// Scaffolding only: maps from the existing UXKit `chromeSnapshot`.
    var chromeViewState: ChromeViewState {
        ChromeViewState(
            isVisible: !chromeSnapshot.isCollapsed, // TODO: map collapsed state to isVisible
            isEditing: chromeSnapshot.isEditing
            // TODO: isInOverview, isOmniboxOverlayVisible, isAddressFocused should be handled in View layer or UXKit
        )
    }
}

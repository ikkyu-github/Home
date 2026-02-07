// ARCH-AUDIT(2026-01-22): SwiftUI-only presentation state. Moved out of SafariLikeKit/Core to keep Core folder UI-free.
import Foundation
import Combine
import SwiftUI
import SafariLikeCoreKit
/// Internal implementation of BrowserUIState.
/// Manages presentation state for views.
@MainActor
final class BrowserUIStateImpl: BrowserUIState {
    // MARK: - Layout Visibility
    @Published var isSidebarVisible = false
    @Published var isTabOverviewVisible = false
    @Published var isBottomBarCollapsed = false
    // MARK: - Progress
    @Published var pageProgress: Double = 0
    // MARK: - Internal State
    enum CompanionSection {
        case bookmarks
        case history
        case downloads
    }
    @Published var activeCompanionSection: CompanionSection? = nil
    @Published var isAutoCompanionEnabled = true
    @Published var relatedAnimation: Animation? = .easeOut(duration: 0.25)
    init() {
        // Default values already set above
    }
}

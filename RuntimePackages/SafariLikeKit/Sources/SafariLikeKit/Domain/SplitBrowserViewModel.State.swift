import SwiftUI
import SafariLikeCoreKit
import Foundation
import Combine
import CoreGraphics
extension SplitBrowserViewModel.State {
    static func initial() -> Self {
        .init(
            isPrivateMode: false,
            isSidebarVisible: false,
            sidebarContent: .menu,
            isTabOverviewVisible: false,
            isTabOverviewPresented: false,
            canGoBack: false,
            canGoForward: false,
            isLoading: false,
            pageProgress: 0,
            isBottomBarCollapsed: false,
            isAutoCompanionEnabled: true,
            splitRatio: 0.75,
            suggestions: []
        )
    }
}
import SwiftUI
import Foundation
import Combine
import CoreGraphics
extension SplitBrowserViewModel {
    // MARK: - State
    struct State {
        var isPrivateMode: Bool
        var isSidebarVisible: Bool
        var sidebarContent: SidebarContent
        var isTabOverviewVisible: Bool
        var isTabOverviewPresented: Bool
        var canGoBack: Bool
        var canGoForward: Bool
        var isLoading: Bool
        var pageProgress: Double
        var isBottomBarCollapsed: Bool
        var isAutoCompanionEnabled: Bool
        var splitRatio: CGFloat
        var suggestions: [OmniboxSuggestion]
    }
}

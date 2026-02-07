import Foundation
import CoreGraphics
import SwiftUI
import SafariLikeCoreKit
import Combine
@MainActor
final class SplitBrowserState: ObservableObject {
    // MARK: - Navigation
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var pageProgress: Double = 0
    // MARK: - Mode
    @Published var isPrivateMode: Bool = false
    // MARK: - UI State
    @Published var isSidebarVisible: Bool = false
    @Published var sidebarContent: SplitBrowserViewModel.SidebarContent = .menu
    @Published var isTabOverviewVisible: Bool = false
    @Published var isTabOverviewPresented: Bool = false
    @Published var isBottomBarCollapsed: Bool = false
    // MARK: - Companion Flags
    // Legacy container retained for compatibility; Related state is owned by `SplitBrowserViewModel`.
    @Published var isAutoCompanionEnabled: Bool = true
    // MARK: - Layout
    @Published var activePane: SplitBrowserViewModel.ActivePane = .left
    @Published var splitRatio: CGFloat = 0.5
    // MARK: - Collections
    @Published var companionItems: [SafariLikeCoreKit.CompanionItem] = []
    @Published var suggestions: [SplitBrowserViewModel.OmniboxSuggestion] = []
}

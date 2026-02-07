import Foundation
import CoreGraphics
import SwiftUI
import SafariLikeCoreKit
// Extracted UI enums to slim down SplitBrowserViewModel.
@MainActor
extension SplitBrowserViewModel {
    // MARK: - Sidebar content (Safari iPad style)
    public typealias SidebarContent = SafariLikeCoreKit.SidebarContent
    // MARK: - Related presentation (single source of truth)
    public enum RelatedPresentation: Equatable {
        case hidden
        case portraitPopup(heightFraction: CGFloat)
        case landscapeSplit
    }
}

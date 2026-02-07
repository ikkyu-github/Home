import CoreGraphics
import SafariLikeUXKit
import SafariLikeCoreKit
typealias SplitPresentationMode = SplitBrowserViewModel.RelatedPresentation
struct CompanionPresentationDecision: Equatable {
    let presentation: SplitPresentationMode
    let isSidebarVisible: Bool
    let isCompanionVisible: Bool
}
struct CompanionPresentationPolicy {
    enum UserOverride: Equatable {
        case none
        case show
        case hide
    }
    static func decide(
        safeWidth: CGFloat,
        orientation: BrowserOrientation,
        userOverride: UserOverride,
        isAutoEnabled: Bool,
        hasItems: Bool,
        isSidebarVisible: Bool
    ) -> CompanionPresentationDecision {
        _ = safeWidth
        _ = orientation
        // Architectural rule: Related must never reserve width from the WebView.
        // Therefore, we do not allow a landscape split-style presentation here.
        // Landscape should use the overlay path (RelatedChromeState + RelatedOverlayPane).
        let visiblePresentation: SplitPresentationMode = .portraitPopup(heightFraction: 0.66)
        let presentation: SplitPresentationMode = {
            switch userOverride {
            case .hide:
                return .hidden
            case .show:
                return visiblePresentation
            case .none:
                if isAutoEnabled, hasItems {
                    return visiblePresentation
                }
                return .hidden
            }
        }()
        let isCompanionVisible = (presentation != .hidden)
        // Sidebar visibility is currently user-driven; policy passes it through.
        // Keeping it in the decision allows a single apply path in the root view.
        return CompanionPresentationDecision(
            presentation: presentation,
            isSidebarVisible: isSidebarVisible,
            isCompanionVisible: isCompanionVisible
        )
    }
}

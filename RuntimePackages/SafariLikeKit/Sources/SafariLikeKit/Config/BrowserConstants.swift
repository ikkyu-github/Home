import Foundation
import CoreGraphics
import SafariLikeUXKit
import SafariLikeCoreKit
enum BrowserConstants {
    // MARK: - UI Strings
    enum UI {
        static let newTabTitle = UXPolicy.Strings.default.newTabTitle
        static let addressPlaceholder = UXPolicy.Strings.default.addressPlaceholder
        static let microInteractionConfig: MicroInteractionConfig = .init(
            caretBlinkPolicy: .system,
            selectionAnimationDuration: 0.12,
            focusExpandCurve: .init(response: 0.28, dampingFraction: 0.88, blendDuration: 0),
            cancelButtonRevealThreshold: 0.55,
            scrollCollapseCouplingStrength: 0.85
        )
    }
    // MARK: - UI Metrics
    enum Metrics {
        enum Toolbar {
            static let height: CGFloat = 44
            static let horizontalPadding: CGFloat = 12
            static let verticalPadding: CGFloat = 8
        }
        enum AddressBar {
            static let minHeight: CGFloat = 36
            static let cornerRadius: CGFloat = 10
            static let horizontalPadding: CGFloat = 10
        }
        enum Tabs {
            static let stripHeight: CGFloat = 44
            static let pillHeight: CGFloat = 30
            static let pillCornerRadius: CGFloat = 10
        }
        enum Radius {
            static let small: CGFloat = 6
            static let medium: CGFloat = 10
            static let large: CGFloat = 14
        }
        enum Animation {
            static let quick: Double = 0.18
            static let standard: Double = 0.25
        }
    }
    /// Keep a stable default that matches framework defaults.
    /// Apps can override per scene via `SafariLikeConfiguration`.
    static let defaultHomeURLString: String = SafariLikeConfiguration.default.defaultHomeURLString
    static let defaultHome = defaultHomeURLString
    /// Minimum split pane width to keep UI stable like Safari iPad.
    static let minPaneWidth: CGFloat = 320
    /// Default primary split ratio (kept for compatibility; layout is driven by configuration).
    static let fixedPrimarySplitRatio: CGFloat = 0.75
    /// Left edge swipe region (pt) for revealing sidebar.
    static let sidebarEdgeRevealWidth: CGFloat = 22
    /// Sidebar width default.
    static let sidebarWidth: CGFloat = 320
}

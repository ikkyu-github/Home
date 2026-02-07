import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
public struct BrowserLayoutResolution: Equatable {
    public let layout: BrowserLayout
    public let orientation: BrowserOrientation
    /// Width excluding safe-area insets.
    public let safeWidth: CGFloat
    /// Convenience.
    public var isLandscape: Bool { orientation == .landscape }
    public var isSplit: Bool { layout == .splitPane }
}
/// Centralized rules for resolving browser layout.
///
/// Inputs:
/// - Device class: approximated via SwiftUI `horizontalSizeClass`
/// - Orientation: from the container size
/// - User preference: controls whether split is allowed at all
public struct BrowserLayoutResolver {
    public init() {}
    public static func orientation(for containerSize: CGSize) -> BrowserOrientation {
        containerSize.width > containerSize.height ? .landscape : .portrait
    }
    public func resolve(
        containerSize: CGSize,
        safeAreaInsets: EdgeInsets,
        horizontalSizeClass: UserInterfaceSizeClass?,
        uxPolicy: UXPolicy = .default,
        configuration: SafariLikeConfiguration,
        userPreference: BrowserLayoutUserPreference = .automatic
    ) -> BrowserLayoutResolution {
        let orientation: BrowserOrientation = Self.orientation(for: containerSize)
        let safeWidth = max(0, containerSize.width - safeAreaInsets.leading - safeAreaInsets.trailing)
        // UI policy: do not branch by device idiom; split behavior is consistent by width.
        _ = horizontalSizeClass
        _ = configuration
        let allowsSplitByWidth = safeWidth >= uxPolicy.splitBrowser.splitEnabledMinWidth
        let wantsSplit: Bool = {
            switch userPreference {
            case .singlePaneOnly:
                return false
            case .preferSplitWhenPossible:
                return true
            case .automatic:
                // Default: preserve existing feel (split affordances in landscape).
                return true
            }
        }()
        let layout: BrowserLayout = (orientation == .landscape && wantsSplit && allowsSplitByWidth) ? .splitPane : .singlePane
        return BrowserLayoutResolution(layout: layout, orientation: orientation, safeWidth: safeWidth)
    }
}

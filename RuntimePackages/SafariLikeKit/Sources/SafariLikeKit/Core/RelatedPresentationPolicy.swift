import SwiftUI
import SafariLikeCoreKit
// MARK: - Canonical Related Presentation Policy
public enum RelatedPresentationPolicy: Sendable, Equatable {
    case hidden
    case overlay(edge: Edge)
    case sidebar(width: CGFloat)
    public static func resolve(
        layoutMode: BrowserLayoutMode,
        isVisible: Bool,
        safeWidth: CGFloat,
        configuration: SafariLikeConfiguration
    ) -> RelatedPresentationPolicy {
        guard isVisible else { return .hidden }
        switch layoutMode {
        case .phonePortrait:
            return .overlay(edge: .bottom)
        case .tabletLandscape:
            let proposed = max(0, safeWidth) * configuration.companionWidthFraction
            let width = min(420, max(280, proposed))
            return .sidebar(width: width)
        @unknown default:
            return .overlay(edge: .bottom)
        }
    }

    /// Legacy resolver signature retained for older UI call sites.
    ///
    /// New code should prefer `resolve(layoutMode:isVisible:safeWidth:configuration:)`.
    public static func resolve(
        hSize: UserInterfaceSizeClass?,
        isVisible: Bool,
        isLandscape: Bool,
        containerSize: CGSize
    ) -> RelatedPresentationMode {
        RelatedPresentationResolver.resolve(
            hSize: hSize,
            isVisible: isVisible,
            isLandscape: isLandscape,
            containerSize: containerSize
        )
    }
}
public enum RelatedPresentationMode {
    case none
    case sidePane
}
/// Legacy resolver retained for older layouts; do not use for new UI.
public struct RelatedPresentationResolver {
    public static func resolve(
        isCompact: Bool,
        isLandscape: Bool,
        containerSize: CGSize
    ) -> RelatedPresentationMode {
        let usableWidth = containerSize.width
        if isCompact {
            guard isLandscape else { return .none }
            return usableWidth >= 700 ? .sidePane : .none
        }
        return isLandscape ? .sidePane : .none
    }
    public static func resolve(
        hSize: UserInterfaceSizeClass?,
        isVisible: Bool,
        isLandscape: Bool,
        containerSize: CGSize
    ) -> RelatedPresentationMode {
        guard isVisible else { return .none }
        let isCompact = (hSize == .compact)
        return resolve(
            isCompact: isCompact,
            isLandscape: isLandscape,
            containerSize: containerSize
        )
    }
}
public struct RelatedLayoutPolicy {
    public static func width(for size: CGSize) -> CGFloat {
        min(360, max(0, size.width * 0.33))
    }
    public static func sidebarWidth(safeWidth: CGFloat, configuration: SafariLikeConfiguration) -> CGFloat {
        let proposed = max(0, safeWidth) * configuration.companionWidthFraction
        return min(420, max(280, proposed))
    }
}

import SwiftUI
import SafariLikeCoreKit
// MARK: - Canonical Related Presentation Policy
public enum RelatedPresentationPolicy: Sendable, Equatable {
    case hidden
    case overlay(edge: Edge)
    case sidebar(width: CGFloat)

    internal static func effectivePresentation(
        relatedPresentation: RelatedPresentationPolicy,
        overviewActive: Bool
    ) -> RelatedPresentationPolicy {
        overviewActive ? .hidden : relatedPresentation
    }

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
}


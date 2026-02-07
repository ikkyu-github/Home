import CoreGraphics

public enum PaneRole: Sendable {
    case web
    case related
}

public struct PaneLayout: Sendable, Equatable {
    public let webWidth: CGFloat
    public let relatedWidth: CGFloat
    public let showRelated: Bool

    public init(webWidth: CGFloat, relatedWidth: CGFloat, showRelated: Bool) {
        self.webWidth = webWidth
        self.relatedWidth = relatedWidth
        self.showRelated = showRelated
    }
}

/// Safari-like lane resolver.
/// - WebContentLane owns a fixed lane; RelatedPane must never resize/overlay it.
public struct PaneLayoutResolver {

    public static func resolve(
        containerSize: CGSize,
        showRelatedRequested: Bool,
        relatedWidth: CGFloat
    ) -> PaneLayout {
        let screenWidth = max(0, containerSize.width)

        guard showRelatedRequested else {
            return PaneLayout(webWidth: screenWidth, relatedWidth: 0, showRelated: false)
        }

        let fixedRelatedWidth = min(max(0, relatedWidth), screenWidth)
        let webWidth = max(0, screenWidth - fixedRelatedWidth)
        return PaneLayout(webWidth: webWidth, relatedWidth: fixedRelatedWidth, showRelated: true)
    }

    public static func resolve(
        containerSize: CGSize,
        showRelatedRequested: Bool,
        maxRelatedWidth: CGFloat = 420
    ) -> PaneLayout {
        let screenWidth = max(0, containerSize.width)

        guard showRelatedRequested else {
            return PaneLayout(webWidth: screenWidth, relatedWidth: 0, showRelated: false)
        }

        let proposedRelated = max(0, screenWidth * 0.33)
        let relatedWidth = min(maxRelatedWidth, proposedRelated)

        let webWidth = max(0, screenWidth - relatedWidth)
        return PaneLayout(webWidth: webWidth, relatedWidth: relatedWidth, showRelated: true)
    }
}

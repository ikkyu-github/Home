import SwiftUI
import SafariLikeCoreKit
public struct BrowserSplitContainer<PrimaryContent: View, RelatedContent: View>: View {
    private let showRelated: Bool
    private let relatedWidth: CGFloat
    @ViewBuilder private let primaryContent: () -> PrimaryContent
    @ViewBuilder private let relatedContent: () -> RelatedContent
    public init(
        showRelated: Bool,
        relatedWidth: CGFloat,
        @ViewBuilder primaryContent: @escaping () -> PrimaryContent,
        @ViewBuilder relatedContent: @escaping () -> RelatedContent
    ) {
        self.showRelated = showRelated
        self.relatedWidth = relatedWidth
        self.primaryContent = primaryContent
        self.relatedContent = relatedContent
    }
    public var body: some View {
        HStack(spacing: 0) {
            primaryContent()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if showRelated {
                relatedContent()
                    .frame(width: relatedWidth)
                    .clipped()
            }
        }
    }
}

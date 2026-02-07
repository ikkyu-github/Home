import SwiftUI
import SafariLikeCoreKit
/// Shared toolbar container that ensures a single trailing Related button.
///
/// - Always shows Related (portrait + landscape).
/// - Does not create or reserve any Related pane.
struct BrowserToolbarView<Content: View>: View {
    let content: Content
    private let relatedAction: () -> Void
    @EnvironmentObject private var relatedChrome: RelatedChromeState
    init(
        relatedAction: @escaping () -> Void = { },
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.relatedAction = relatedAction
    }
    var body: some View {
        HStack(spacing: 12) {
            content
            Spacer(minLength: 8)
            RelatedButton(action: relatedAction)
                .environmentObject(relatedChrome)
        }
        .frame(maxWidth: .infinity)
    }
}

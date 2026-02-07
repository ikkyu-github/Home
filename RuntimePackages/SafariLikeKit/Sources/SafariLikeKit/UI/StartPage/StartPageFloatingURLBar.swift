import SwiftUI
import SafariLikeCoreKit
/// Thin wrapper for the Start Page that forwards into `PhonePortraitBottomBar`.
///
/// `PhonePortraitBottomBar` is the single source of truth for the portrait bottom chrome UI.
internal struct StartPageFloatingURLBar: View {
    @Binding var text: String
    @Binding var barState: StartPageURLBarState
    var onToggleSidebar: () -> Void
    var onToggleRelated: () -> Void
    var onPresentTabOverview: () -> Void
    var onNewTab: () -> Void
    var onBack: () -> Void
    var onForward: () -> Void
    var onReload: () -> Void
    var onSubmitURL: (String) -> Void
    var onAddBookmark: () -> Void
    var onShare: () -> Void
    var body: some View {
        PhonePortraitBottomBar(
            text: $text,
            isEditing: Binding(
                get: { barState == .editing },
                set: { barState = $0 ? .editing : .compact }
            ),
            onToggleSidebar: onToggleSidebar,
            onToggleRelated: onToggleRelated,
            onPresentTabOverview: onPresentTabOverview,
            onNewTab: onNewTab,
            onBack: onBack,
            onForward: onForward,
            onReload: onReload,
            onSubmitURL: onSubmitURL,
            onAddBookmark: onAddBookmark,
            onShare: onShare
        )
    }
}

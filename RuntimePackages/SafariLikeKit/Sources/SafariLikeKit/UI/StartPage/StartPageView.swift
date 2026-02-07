import SwiftUI
import SafariLikeUXKit
import SafariLikeCoreKit
internal struct StartPageView: View {
    @StateObject private var model: StartPageViewModel
    /// Root-provided safe area insets.
    /// Note: Start Page layout should be hosted in a safe-area respecting container.
    let safeAreaInsets: EdgeInsets
    @State private var floatingBarHeight: CGFloat = 0
    init(
        bookmarkStore: BookmarkStore,
        readingListStore: ReadingListStore,
        onSubmitQueryOrURLString: @escaping (String) -> Void,
        onOpenURLString: @escaping (String) -> Void,
        onToggleSidebar: @escaping () -> Void,
        onToggleRelated: @escaping () -> Void,
        onPresentTabOverview: @escaping () -> Void,
        onNewTab: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void,
        onReload: @escaping () -> Void,
        onAddBookmark: @escaping () -> Void,
        onShare: @escaping () -> Void,
        safeAreaInsets: EdgeInsets
    ) {
        self.safeAreaInsets = safeAreaInsets
        let handler = StartPageClosureActionHandler(
            onSubmitQueryOrURLString: onSubmitQueryOrURLString,
            onOpenURLString: onOpenURLString,
            onToggleSidebar: onToggleSidebar,
            onToggleRelated: onToggleRelated,
            onPresentTabOverview: onPresentTabOverview,
            onNewTab: onNewTab,
            onBack: onBack,
            onForward: onForward,
            onReload: onReload
        )
        _model = StateObject(
            wrappedValue: StartPageViewModel(
                bookmarkStore: bookmarkStore,
                readingListStore: readingListStore,
                handler: handler
            )
        )

		self.onAddBookmark = onAddBookmark
		self.onShare = onShare
    }
	private let onAddBookmark: () -> Void
	private let onShare: () -> Void
    var body: some View {
        ZStack(alignment: .bottom) {
            StartPageBackgroundView()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 24) {
                        Color.clear.frame(height: max(0, safeAreaInsets.top + 16))
                        StartPageHeaderView()
                        if model.favorites.isEmpty == false {
                            TopSitesGrid(
                                items: model.favorites,
                                onOpenURLString: { urlString in
                                    model.send(.openURLString(urlString))
                                }
                            )
                        }
                        if model.readingListPreview.isEmpty == false {
                            StartPageReadingListView(
                                items: model.readingListPreview,
                                onOpenItem: { item in
                                    model.send(.openReadingListItem(id: item.id))
                                }
                            )
                        }
                    }
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                }
                .padding(.horizontal, DeviceLayout.horizontalPadding)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                // Spacer only: must not steal taps from the floating toolbar.
                Color.clear
                    .frame(height: floatingBarHeight)
                    .allowsHitTesting(false)
            }
            StartPageFloatingURLBar(
                text: $model.urlBarText,
                barState: $model.urlBarState,
                onToggleSidebar: { model.send(.toggleSidebar) },
                onToggleRelated: { model.send(.toggleRelated) },
                onPresentTabOverview: { model.send(.presentTabOverview) },
                onNewTab: { model.send(.newTab) },
                onBack: { model.send(.goBack) },
                onForward: { model.send(.goForward) },
                onReload: { model.send(.reload) },
                onSubmitURL: { text in model.send(.submitQueryOrURLString(text)) },
				onAddBookmark: onAddBookmark,
				onShare: onShare
            )
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(key: FloatingBarHeightPreferenceKey.self, value: geo.size.height)
                        .allowsHitTesting(false)
                }
            )
        }
        .onPreferenceChange(FloatingBarHeightPreferenceKey.self) { floatingBarHeight = $0 }
    }
}
@MainActor
private final class StartPageClosureActionHandler: StartPageActionHandling {
    private let onSubmitQueryOrURLString: (String) -> Void
    private let onOpenURLString: (String) -> Void
    private let onToggleSidebar: () -> Void
    private let onToggleRelated: () -> Void
    private let onPresentTabOverview: () -> Void
    private let onNewTab: () -> Void
    private let onBack: () -> Void
    private let onForward: () -> Void
    private let onReload: () -> Void
    init(
        onSubmitQueryOrURLString: @escaping (String) -> Void,
        onOpenURLString: @escaping (String) -> Void,
        onToggleSidebar: @escaping () -> Void,
        onToggleRelated: @escaping () -> Void,
        onPresentTabOverview: @escaping () -> Void,
        onNewTab: @escaping () -> Void,
        onBack: @escaping () -> Void,
        onForward: @escaping () -> Void,
        onReload: @escaping () -> Void
    ) {
        self.onSubmitQueryOrURLString = onSubmitQueryOrURLString
        self.onOpenURLString = onOpenURLString
        self.onToggleSidebar = onToggleSidebar
        self.onToggleRelated = onToggleRelated
        self.onPresentTabOverview = onPresentTabOverview
        self.onNewTab = onNewTab
        self.onBack = onBack
        self.onForward = onForward
        self.onReload = onReload
    }
    func handle(_ action: StartPageAction) {
        switch action {
        case .submitQueryOrURLString(let text):
            onSubmitQueryOrURLString(text)
        case .openURLString(let urlString):
            onOpenURLString(urlString)
        case .openReadingListItem:
            // This is handled within StartPageViewModel (mark opened), then forwarded as .openURLString.
            break
        case .toggleSidebar:
            onToggleSidebar()
        case .toggleRelated:
            onToggleRelated()
        case .presentTabOverview:
            onPresentTabOverview()
        case .newTab:
            onNewTab()
        case .goBack:
            onBack()
        case .goForward:
            onForward()
        case .reload:
            onReload()
        }
    }
}
private struct FloatingBarHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
private struct StartPageHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Start Page")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
            Text("Favorites and Reading List")
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}

import SwiftUI
import UIKit
import Combine
import SafariLikeUXKit
import SafariLikeCoreKit
/// Renderer for `BrowserTab.State.startPage`.
internal struct StartPageRenderer: View {
    @ObservedObject var vm: SplitBrowserViewModel
    @ObservedObject var relatedChrome: RelatedChromeState
    let safeAreaInsets: EdgeInsets
    @StateObject private var model: StartPageViewModel
    init(vm: SplitBrowserViewModel, relatedChrome: RelatedChromeState, safeAreaInsets: EdgeInsets) {
        self.vm = vm
        self.relatedChrome = relatedChrome
        self.safeAreaInsets = safeAreaInsets
        let handler = StartPageClosureActionHandler(
            onSubmitQueryOrURLString: { text in
                vm.send(.openURLString(text))
            },
            onOpenURLString: { urlString in
                vm.send(.openURLString(urlString))
            },
            onToggleSidebar: { vm.toggleSidebar() },
            onToggleRelated: {
                relatedChrome.toggle(animation: vm.relatedAnimation ?? .easeOut(duration: 0.25))
            },
            onPresentTabOverview: { vm.presentTabOverview() },
            onNewTab: { vm.send(.newTab()) },
            onBack: { vm.send(.goBack) },
            onForward: { vm.send(.goForward) },
            onReload: { vm.send(.reload) }
        )
        _model = StateObject(
            wrappedValue: StartPageViewModel(
                bookmarkStore: vm.bookmarkStore,
                readingListStore: vm.readingListStore,
                handler: handler
            )
        )
    }
    var body: some View {
        ZStack {
            // Safari-like: neutral system background + subtle depth.
            StartPageSystemBackground()

            // UIKit-backed scroll for smooth, continuous scrolling.
            // IMPORTANT: Start Page is content-only; bottom chrome is owned by the parent
            // layout (reserved via safeAreaInset), not overlaid inside this renderer.
            StartPageScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        // Top breathing room like Safari Start Page.
                        Color.clear
                            .frame(height: max(0, safeAreaInsets.top + 22))
                        StartPageTitleHeader()
                        if model.favorites.isEmpty == false {
                            FavoritesSection(
                                items: model.favorites,
                                onOpenURLString: { urlString in
                                    model.send(.openURLString(urlString))
                                }
                            )
                        }
                        if model.readingListPreview.isEmpty == false {
                            ReadingListSection(
                                items: model.readingListPreview,
                                onOpenItem: { item in
                                    model.send(.openReadingListItem(id: item.id))
                                }
                            )
                        }
                        // Bottom breathing room so last section doesn't feel cramped.
                        Color.clear.frame(height: 28)
                    }
                    .frame(maxWidth: DeviceLayout.contentMaxWidth)
                    .padding(.horizontal, DeviceLayout.horizontalPadding)
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 28)
            }
        }
    }
}
// MARK: - Safari-like background
private struct StartPageSystemBackground: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
            // Subtle top gradient (Safari-like depth without custom artwork).
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.00)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.overlay)
        }
    }
}
private struct StartPageTitleHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Start Page")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            Text("Favorites and Reading List")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
// MARK: - Favorites
private struct FavoritesSection: View {
    let items: [BrowserBookmark]
    let onOpenURLString: (String) -> Void
    private var columns: [GridItem] {
        // Adaptive grid like Safari: as width grows, more columns appear.
        [GridItem(.adaptive(minimum: 84, maximum: 96), spacing: 14, alignment: .top)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorites")
                .font(.headline)
                .foregroundStyle(.primary)
            LazyVGrid(columns: columns, alignment: .center, spacing: 18) {
                ForEach(items.prefix(8)) { item in
                    Button {
                        onOpenURLString(item.urlString)
                    } label: {
                        FavoriteTile(title: item.title)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}
private struct FavoriteTile: View {
    let title: String
    var body: some View {
        VStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                }
                .frame(width: 84, height: 84)
                .overlay {
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.80))
                }
            Text(title)
                .font(.footnote)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 92)
        }
        .contentShape(Rectangle())
    }
}
// MARK: - Reading List
private struct ReadingListSection: View {
    let items: [BrowserReadingListItem]
    let onOpenItem: (BrowserReadingListItem) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Reading List")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
            }
            VStack(spacing: 10) {
                ForEach(items.prefix(4)) { item in
                    Button {
                        onOpenItem(item)
                    } label: {
                        ReadingListRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
private struct ReadingListRow: View {
    let item: BrowserReadingListItem
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Image(systemName: item.isRead ? "book" : "book.closed")
                        .foregroundStyle(.primary.opacity(0.80))
                }
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(item.urlString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
        )
    }
}
// MARK: - UIKit scroll bridge
private struct StartPageScrollView<Content: View>: UIViewRepresentable {
    let showsIndicators: Bool
    let content: Content
    init(showsIndicators: Bool, @ViewBuilder content: () -> Content) {
        self.showsIndicators = showsIndicators
        self.content = content()
    }
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.keyboardDismissMode = .interactive
        scrollView.delaysContentTouches = false
        scrollView.backgroundColor = .clear
        let host = context.coordinator.hostingController
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        return scrollView
    }
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        uiView.showsVerticalScrollIndicator = showsIndicators
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(rootView: content)
    }
    final class Coordinator {
        let hostingController: UIHostingController<Content>
        init(rootView: Content) {
            self.hostingController = UIHostingController(rootView: rootView)
        }
    }
}
// MARK: - Action handler
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
        case .openReadingListItem(id: _):
            // StartPageViewModel handles this by marking opened and routing to `.openURLString`.
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

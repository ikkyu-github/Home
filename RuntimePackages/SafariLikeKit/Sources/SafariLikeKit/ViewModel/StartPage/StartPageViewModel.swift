import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
public final class StartPageViewModel: ObservableObject {
    @Published public private(set) var favorites: [BrowserBookmark] = []
    @Published public private(set) var readingListPreview: [BrowserReadingListItem] = []
    @Published internal var urlBarText: String = ""
    @Published internal var urlBarState: StartPageURLBarState = .compact
    private let bookmarkStore: BookmarkStore
    private let readingListStore: ReadingListStore
    private let handler: any StartPageActionHandling
    private var cancellables: Set<AnyCancellable> = []
    public init(
        bookmarkStore: BookmarkStore,
        readingListStore: ReadingListStore,
        handler: any StartPageActionHandling
    ) {
        self.bookmarkStore = bookmarkStore
        self.readingListStore = readingListStore
        self.handler = handler
        // Seed immediately (so the UI doesn't flash empty after mount).
        self.favorites = Array(bookmarkStore.items.prefix(8))
        self.readingListPreview = Array(readingListStore.items.prefix(4))
        bookmarkStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.favorites = Array(items.prefix(8))
            }
            .store(in: &cancellables)
        readingListStore.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                self?.readingListPreview = Array(items.prefix(4))
            }
            .store(in: &cancellables)
    }
    public func send(_ action: StartPageAction) {
        switch action {
        case .openReadingListItem(let id):
            readingListStore.markOpened(id: id)
            if let item = readingListStore.items.first(where: { $0.id == id }) {
                handler.handle(.openURLString(item.urlString))
            }
        case .openURLString:
            handler.handle(action)
        case .submitQueryOrURLString(let text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            urlBarText = ""
            urlBarState = .compact
            handler.handle(.submitQueryOrURLString(trimmed))
        case .toggleSidebar, .toggleRelated, .presentTabOverview, .newTab, .goBack, .goForward, .reload:
            handler.handle(action)
        }
    }
}

import SwiftUI
import Foundation
import SafariLikeCoreKit
private struct TrailingTrashToolbarModifier: ViewModifier {
    let isEmpty: Bool
    let removeAll: () -> Void
    @ViewBuilder
    private var trashButton: some View {
        if !isEmpty {
            Button(role: .destructive) {
                removeAll()
            } label: {
                Image(systemName: "trash")
            }
        }
    }
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar {
                ToolbarItem(placement: .topBarTrailing) { trashButton }
            }
        } else {
            content.toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { trashButton }
            }
        }
    }
}
/// Safari iPad style sidebar pane.
///
/// In landscape this is a *real pane* that pushes the web content.
/// In portrait this is embedded inside the overlay drawer.
internal struct SidebarPaneView: View {
    @ObservedObject var vm: SplitBrowserViewModel
    let isOverlay: Bool
    let onSelect: (SidebarView.Item) -> Void
    private var onOpenURLString: (String) -> Void {
        { urlString in
            guard let url = URL(string: urlString) else { return }
            vm.open(url)
        }
    }
    private var dismissOverlayIfNeeded: () -> Void {
        {
            if isOverlay {
                vm.setSidebarVisible(false)
            }
        }
    }
    var body: some View {
        switch vm.sidebarContent {
        case .menu:
            SidebarView(onSelect: { item in
                onSelect(item)
                dismissOverlayIfNeeded()
            })
        case .bookmarks:
                SidebarLibraryContainer(
                    title: "Bookmarks",
                    systemImage: "book",
                    isOverlay: isOverlay,
                    onBack: { vm.showSidebar(content: .menu) }
                ) {
                    BookmarksSidebarList(
                        store: vm.bookmarkStore,
                        onOpen: { urlString in
                            onOpenURLString(urlString)
                            dismissOverlayIfNeeded()
                        }
                    )
                }
        case .readingList:
                SidebarLibraryContainer(
                    title: "Reading List",
                    systemImage: "eyeglasses",
                    isOverlay: isOverlay,
                    onBack: { vm.showSidebar(content: .menu) }
                ) {
                    ReadingListSidebarList(
                        store: vm.readingListStore,
                        onOpen: { urlString, id in
                            vm.readingListStore.markOpened(id: id)
                            onOpenURLString(urlString)
                            dismissOverlayIfNeeded()
                        }
                    )
                }
        case .history:
                SidebarLibraryContainer(
                    title: "History",
                    systemImage: "clock",
                    isOverlay: isOverlay,
                    onBack: { vm.showSidebar(content: .menu) }
                ) {
                    HistorySidebarList(
                        store: vm.historyStore,
                        onOpen: { urlString in
                            onOpenURLString(urlString)
                            dismissOverlayIfNeeded()
                        }
                    )
                }
            @unknown default:
                SidebarView(onSelect: { item in
                    onSelect(item)
                })
        }
    }
}
// MARK: - Common container (header + content)
// Moved to Components/SidebarLibraryContainer.swift
// MARK: - Bookmarks
internal struct BookmarksSidebarList: View {
    @ObservedObject var store: BookmarkStore
    let onOpen: (String) -> Void
    @State private var query: String = ""
    @State private var renaming: BrowserBookmark?
    @State private var renameText: String = ""
    private var filteredItems: [BrowserBookmark] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.urlString.localizedCaseInsensitiveContains(q)
        }
    }
    var body: some View {
        List {
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "book")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No Bookmarks")
                        .font(.headline)
                    Text("Save pages you want to revisit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredItems) { item in
                    Button {
                        onOpen(item.urlString)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.system(size: 15, weight: .medium))
                                .lineLimit(2)
                            Text(item.urlString)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                    .contextMenu {
                        Button("Rename") {
                            renaming = item
                            renameText = item.title
                        }
                        Button(role: .destructive) {
                            store.remove(id: item.id)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
                .onDelete { indexSet in
                    let items = filteredItems
                    for idx in indexSet {
                        store.remove(id: items[idx].id)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .modifier(TrailingTrashToolbarModifier(isEmpty: store.items.isEmpty, removeAll: { store.removeAll() }))
        .alert("Rename Bookmark", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let item = renaming {
                    store.rename(id: item.id, newTitle: renameText)
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
}
// MARK: - Reading List
internal struct ReadingListSidebarList: View {
    @ObservedObject var store: ReadingListStore
    let onOpen: (String, UUID) -> Void
    @State private var query: String = ""
    @State private var renaming: BrowserReadingListItem?
    @State private var renameText: String = ""
    private var filteredItems: [BrowserReadingListItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.urlString.localizedCaseInsensitiveContains(q)
        }
    }
    var body: some View {
        List {
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No Reading List")
                        .font(.headline)
                    Text("Save articles to read later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(filteredItems) { item in
                    Button {
                        onOpen(item.urlString, item.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.isRead ? "circle" : "circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(item.isRead ? .tertiary : .primary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .lineLimit(2)
                                Text(item.urlString)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .contextMenu {
                        Button(item.isRead ? "Mark Unread" : "Mark Read") {
                            store.markRead(id: item.id, isRead: !item.isRead)
                        }
                        Button("Rename") {
                            renaming = item
                            renameText = item.title
                        }
                        Button(role: .destructive) {
                            store.remove(id: item.id)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
                .onDelete { indexSet in
                    let items = filteredItems
                    for idx in indexSet {
                        store.remove(id: items[idx].id)
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .modifier(TrailingTrashToolbarModifier(isEmpty: store.items.isEmpty, removeAll: { store.removeAll() }))
        .alert("Rename Item", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } }
        )) {
            TextField("Title", text: $renameText)
            Button("Save") {
                if let item = renaming {
                    store.rename(id: item.id, newTitle: renameText)
                }
                renaming = nil
            }
            Button("Cancel", role: .cancel) { renaming = nil }
        }
    }
}
// MARK: - History
internal struct HistorySidebarList: View {
    @ObservedObject var store: HistoryStore
    let onOpen: (String) -> Void
    @State private var query: String = ""
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    private var filteredItems: [BrowserHistoryItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return store.items }
        return store.items.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.urlString.localizedCaseInsensitiveContains(q)
        }
    }
    /// Groups history items into sections by day.
    private var sections: [(String, [BrowserHistoryItem])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredItems) { item in
            calendar.startOfDay(for: item.visitedAt)
        }
        let sortedDays = grouped.keys.sorted(by: >)
        return sortedDays.map { day in
            (Self.dayFormatter.string(from: day), grouped[day]?.sorted(by: { $0.visitedAt > $1.visitedAt }) ?? [])
        }
    }
    var body: some View {
        List {
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(.secondary)
                    Text("No History")
                        .font(.headline)
                    Text("Pages you visit will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(sections, id: \.0) { sectionTitle, items in
                    Section(sectionTitle) {
                        ForEach(items) { item in
                            Button {
                                onOpen(item.urlString)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title.isEmpty ? item.urlString : item.title)
                                        .font(.system(size: 15, weight: .medium))
                                        .lineLimit(2)
                                    Text(item.urlString)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 2)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.remove(id: item.id)
                                } label: {
                                    Text("Delete")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for idx in indexSet {
                                store.remove(id: items[idx].id)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .modifier(TrailingTrashToolbarModifier(isEmpty: store.items.isEmpty, removeAll: { store.removeAll() }))
    }
}

import SwiftUI
import Foundation
import SafariLikeCoreKit
internal struct BookmarksSheetView: View {
    @ObservedObject var store: BookmarkStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss
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
        LibrarySheetNavigationScaffold(
            title: "Bookmarks",
            showsClearButton: !store.items.isEmpty,
            onClear: { store.removeAll() }
        ) {
            listContent
        }
    }
    private var listContent: some View {
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
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 16, weight: .medium))
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

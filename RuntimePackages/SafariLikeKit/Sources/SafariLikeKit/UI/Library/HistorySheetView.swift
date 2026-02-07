import SwiftUI
import Foundation
import SafariLikeCoreKit
internal struct HistorySheetView: View {
    @ObservedObject var store: HistoryStore
    let onOpen: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    private struct DaySection: Identifiable {
        let id: Date
        let title: String
        let items: [BrowserHistoryItem]
    }
    private static let dayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt
    }()
    private var sections: [DaySection] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [BrowserHistoryItem] = q.isEmpty ? store.items : store.items.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.urlString.localizedCaseInsensitiveContains(q)
        }
        let cal = Calendar.current
        let grouped = Dictionary(grouping: base) { item in
            cal.startOfDay(for: item.visitedAt)
        }
        return grouped
            .keys
            .sorted(by: >)
            .map { day in
                let items = (grouped[day] ?? []).sorted { $0.visitedAt > $1.visitedAt }
                return DaySection(id: day, title: Self.dayFormatter.string(from: day), items: items)
            }
    }
    var body: some View {
        LibrarySheetNavigationScaffold(
            title: "History",
            showsClearButton: !store.items.isEmpty,
            onClear: { store.removeAll() }
        ) {
            listContent
        }
    }
    private var listContent: some View {
        List {
                if store.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 40, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("No History")
                            .font(.headline)
                        Text("Pages you visit will show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(sections) { section in
                        Section(section.title) {
                            ForEach(section.items) { item in
                                Button {
                                    onOpen(item.urlString)
                                    dismiss()
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .medium))
                                            .lineLimit(2)
                                        HStack(spacing: 8) {
                                            Text(item.urlString)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                            Spacer(minLength: 0)
                                            Text(item.visitedAt, style: .time)
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        }
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
                                let items = section.items
                                for idx in indexSet {
                                    store.remove(id: items[idx].id)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
    }
}

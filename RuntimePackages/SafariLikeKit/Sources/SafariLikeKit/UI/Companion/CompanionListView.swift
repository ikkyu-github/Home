import SwiftUI
import SafariLikeCoreKit
import SafariLikeUXKit
#if canImport(UIKit)
import UIKit
#endif
// BUILD-PERF-AUDIT(2026-01-21): Compile hotspot (SwiftUI view + UIKit-conditional compilation).
// Keep conditional imports narrow; avoid adding extra dependencies here.
struct CompanionListView: View {
    @Environment(\.uxPolicy) private var uxPolicy
    let items: [CompanionItem]
    let currentURLString: String?
    let onSelect: (CompanionItem) -> Void
    /// Optional UX actions (safe defaults keep existing call sites working)
    var onClose: (() -> Void)? = nil
    var onOpenInNewTab: ((CompanionItem) -> Void)? = nil
    var onCopyLink: ((CompanionItem) -> Void)? = nil
    @FocusState private var isSearchFocused: Bool
    @StateObject private var model = CompanionListViewModel()
    @State private var pendingOpenItem: CompanionItem? = nil
    init(
        items: [CompanionItem],
        currentURLString: String?,
        onSelect: @escaping (CompanionItem) -> Void,
        onClose: (() -> Void)? = nil,
        onOpenInNewTab: ((CompanionItem) -> Void)? = nil,
        onCopyLink: ((CompanionItem) -> Void)? = nil
    ) {
        self.items = items
        self.currentURLString = currentURLString
        self.onSelect = onSelect
        self.onClose = onClose
        self.onOpenInNewTab = onOpenInNewTab
        self.onCopyLink = onCopyLink
        #if DEBUG
        let url = currentURLString ?? "nil"
        print("[CompanionListView][Init] items=\(items.count) url=\(url)")
        #endif
    }
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
        .clipped()
        .onAppear {
            self.model.update(items: self.items, currentURLString: self.currentURLString)
        }
        .onChange(of: items) { newItems in
            self.model.update(items: newItems, currentURLString: self.currentURLString)
        }
        .onChange(of: currentURLString) { newURL in
            self.model.update(items: self.items, currentURLString: newURL)
        }
        .onChange(of: model.searchText) { _ in
            self.model.update(items: self.items, currentURLString: self.currentURLString)
        }
        .onChange(of: model.filter) { _ in
            self.model.update(items: self.items, currentURLString: self.currentURLString)
        }
        .sheet(item: $model.quickPeekItem) { item in
            QuickPeekSheet(
                item: item,
                onClose: { model.dismissQuickPeek() },
                onOpen: {
                    model.dismissQuickPeek()
                    onSelect(item)
                },
                onOpenInNewTab: onOpenInNewTab == nil ? nil : {
                    model.dismissQuickPeek()
                    onOpenInNewTab?(item)
                }
            )
        }
    }
    // MARK: - Quick Peek
    private struct QuickPeekSheet: View {
        let item: CompanionItem
        let onClose: () -> Void
        let onOpen: () -> Void
        let onOpenInNewTab: (() -> Void)?
        var body: some View {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        sheetContent
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Close", action: onClose)
                                }
                            }
                    }
                } else {
                    NavigationView {
                        sheetContent
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Close", action: onClose)
                                }
                            }
                    }
                    .navigationViewStyle(.stack)
                }
            }
            .modifier(DetentsIfAvailable())
        }
        private var sheetContent: some View {
            VStack(alignment: .leading, spacing: 14) {
                Text(item.title.isEmpty ? item.urlString : item.title)
                    .font(.headline)
                    .lineLimit(3)
                Text(item.urlString)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let hint = item.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 10) {
                    Button(action: onOpen) {
                        Label("Open", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    if let onOpenInNewTab {
                        Button(action: onOpenInNewTab) {
                            Label("Open in New Tab", systemImage: "plus.square.on.square")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(18)
            .navigationTitle("Quick Peek")
            .navigationBarTitleDisplayMode(.inline)
        }
        private struct DetentsIfAvailable: ViewModifier {
            func body(content: Content) -> some View {
                if #available(iOS 16.0, *) {
                    content
                        .presentationDetents([.medium, .large])
                } else {
                    content
                }
            }
        }
    }
    @ViewBuilder
    private var content: some View {
        if model.sections.flatMap({ $0.items }).isEmpty {
            emptyState
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 18)
        } else {
            List {
                ForEach(model.sections) { section in
                    Section {
                        if !section.isCollapsed {
                            ForEach(section.items) { item in
                                row(item)
                                    .listRowSeparator(.hidden)
                                    .listRowBackground(Color.black)
                            }
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
            .listStyle(.plain)
            .listSectionSeparator(.hidden)
            .scrollContentBackgroundHiddenCompat()
            .background(Color.black)
        }
    }
    private var header: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Related")
                    .font(.headline)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let onClose {
                    Button {
                        isSearchFocused = false
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close Related")
                }
            }
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search related…", text: $model.searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .focused($isSearchFocused)
                    if !model.searchText.isEmpty {
                        Button {
                            model.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Menu {
                    Picker("Filter", selection: $model.filter) {
                        ForEach(CompanionListViewModel.Filter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Filter")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    private func row(_ item: CompanionItem) -> some View {
        Button {
            // Preview before opening
            model.presentQuickPeek(item)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.ultraThinMaterial)
                    Image(systemName: "link")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title.isEmpty ? displayHost(item.urlString) : item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(displaySubtitle(item))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 10)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDrag {
            if let url = URL(string: item.urlString) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: item.urlString as NSString)
        }
        .contextMenu {
            Button { onSelect(item) } label: { Label("Open", systemImage: "arrow.up.right.square") }
            if let onOpenInNewTab {
                Button {
                    onOpenInNewTab(item)
                } label: {
                    Label("Open in New Tab", systemImage: "plus.square.on.square")
                }
            }
            Button {
                copyLink(item)
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let onOpenInNewTab {
                Button {
                    onOpenInNewTab(item)
                } label: {
                    Label(uxPolicy.strings.newTabTitle, systemImage: "plus.square.on.square")
                }
                .tint(.blue)
            }
            Button {
                copyLink(item)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .tint(.gray)
        }
    }
    private func sectionHeader(_ section: CompanionListViewModel.Section) -> some View {
        Button {
            model.toggleSection(section.id)
        } label: {
            HStack(spacing: 10) {
                Text(section.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: section.isCollapsed ? "chevron.down" : "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No related links yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Open a page with links and this pane will populate automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    private func displayHost(_ urlString: String) -> String {
        guard let url = URL(string: urlString) else { return urlString }
        return url.host ?? urlString
    }
    private func displaySubtitle(_ item: CompanionItem) -> String {
        if let hint = item.hint, !hint.isEmpty {
            return hint
        }
        return item.urlString
    }
    private func copyLink(_ item: CompanionItem) {
        if let onCopyLink {
            onCopyLink(item)
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = item.urlString
        #endif
    }
}
private struct ScrollContentBackgroundHiddenCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .scrollContentBackground(.hidden)
        } else {
            content
                .onAppear {
                    #if canImport(UIKit)
                    UITableView.appearance().backgroundColor = UIColor.black
                    UITableViewCell.appearance().backgroundColor = UIColor.black
                    #endif
                }
        }
    }
}
private extension View {
    func scrollContentBackgroundHiddenCompat() -> some View {
        self.modifier(ScrollContentBackgroundHiddenCompat())
    }
}
#if DEBUG
struct CompanionListView_Previews: PreviewProvider {
    static var previews: some View {
        CompanionListView(
            items: [
                CompanionItem(title: "Example 1", urlString: "https://example.com/1", hint: "Same site"),
                CompanionItem(title: "Example 2", urlString: "https://example.com/2", hint: "Another link")
            ],
            currentURLString: "https://example.com",
            onSelect: { _ in }
        )
        .previewLayout(.sizeThatFits)
        .frame(width: 360, height: 520)
        .preferredColorScheme(.dark)
    }
}
#endif

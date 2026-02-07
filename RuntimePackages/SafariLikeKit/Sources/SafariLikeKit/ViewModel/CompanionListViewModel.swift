import Foundation
import Combine
import SafariLikeCoreKit
@MainActor
final class CompanionListViewModel: ObservableObject {
    struct Section: Identifiable, Equatable {
        let id: String
        let title: String
        var items: [CompanionItem]
        var isCollapsed: Bool
    }
    enum Filter: String, CaseIterable {
        case all = "All"
        case sameHost = "Same Site"
    }
    @Published var searchText: String = ""
    @Published var filter: Filter = .all
    @Published private(set) var sections: [Section] = []
    @Published var quickPeekItem: CompanionItem? = nil
    private var allItems: [CompanionItem] = []
    private var currentHost: String? = nil
    func update(items: [CompanionItem], currentURLString: String?) {
        self.allItems = items
        self.currentHost = Self.host(from: currentURLString)
        rebuildSections()
    }
    func toggleSection(_ id: String) {
        guard let idx = sections.firstIndex(where: { $0.id == id }) else { return }
        sections[idx].isCollapsed.toggle()
    }
    func presentQuickPeek(_ item: CompanionItem) {
        quickPeekItem = item
    }
    func dismissQuickPeek() {
        quickPeekItem = nil
    }
    // MARK: - Internals
    private func rebuildSections() {
        let filtered = applyFilters(allItems)
        // Smart grouping:
        // - Same host section (if any)
        // - Others grouped by host
        var output: [Section] = []
        if let host = currentHost {
            let same = filtered.filter { Self.host(from: $0.urlString) == host }
            if !same.isEmpty {
                output.append(Section(id: "same", title: "Same Site", items: same, isCollapsed: false))
            }
            let other = filtered.filter { Self.host(from: $0.urlString) != host }
            output.append(contentsOf: Self.groupByHost(items: other))
        } else {
            output.append(contentsOf: Self.groupByHost(items: filtered))
        }
        sections = output
    }
    private func applyFilters(_ items: [CompanionItem]) -> [CompanionItem] {
        var out = items
        if filter == .sameHost, let host = currentHost {
            out = out.filter { Self.host(from: $0.urlString) == host }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            out = out.filter {
                $0.title.lowercased().contains(q)
                || $0.urlString.lowercased().contains(q)
                || ($0.hint?.lowercased().contains(q) ?? false)
            }
        }
        return out
    }
    private static func groupByHost(items: [CompanionItem]) -> [Section] {
        let groups = Dictionary(grouping: items) { host(from: $0.urlString) ?? "Other" }
        let orderedKeys = groups.keys.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        return orderedKeys.map { key in
            Section(id: "host:\(key)", title: key, items: groups[key] ?? [], isCollapsed: false)
        }
    }
    private static func host(from urlString: String?) -> String? {
        guard let s = urlString, let url = URL(string: s) else { return nil }
        return url.host?.lowercased()
    }
}

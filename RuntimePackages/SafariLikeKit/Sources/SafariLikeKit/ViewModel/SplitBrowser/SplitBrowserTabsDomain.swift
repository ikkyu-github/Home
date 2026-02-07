import Foundation
import Combine
import CoreGraphics
import SafariLikeCoreKit
@MainActor
final class SplitBrowserTabsDomain: ObservableObject {
	@Published private var _ping = false
	weak var root: SplitBrowserViewModel?
	init(root: SplitBrowserViewModel) { self.root = root }
	// Moved from SplitBrowserViewModel (Tab-related state)
	@Published var activeTabID: UUID? = nil
	@Published var isSplitViewEnabled: Bool = false
	@Published var leftTabID: UUID?
	@Published var rightTabID: UUID?
	@Published var splitViewRatio: CGFloat = 0.5
	@Published var selectedTabGroupID: UUID?
	// MARK: - Tab operations (moved from SplitBrowserViewModel)
	func newTab(inGroup groupID: UUID? = nil) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before newTab(inGroup=\(groupID?.uuidString ?? "nil")) activeTabID=\(activeTabID?.uuidString ?? "nil") leftTabID=\(leftTabID?.uuidString ?? "nil") rightTabID=\(rightTabID?.uuidString ?? "nil") isSplitViewEnabled=\(isSplitViewEnabled)",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		_ = root.tabManager.newTab(inGroup: groupID)
	}
	func newTab() {
		newTab(inGroup: nil)
	}
	func selectTab(_ id: UUID?) {
		guard let id else { return }
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before selectTab(id=\(id.uuidString)) activeTabID=\(activeTabID?.uuidString ?? "nil") leftTabID=\(leftTabID?.uuidString ?? "nil") rightTabID=\(rightTabID?.uuidString ?? "nil")",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		let oldSelected = root.sessionStore.selectedTabID
		root.bar.willSwitch(from: oldSelected)
		root.tabManager.selectTab(id)
		let urlString = root.sessionStore.tabs.first(where: { $0.id == id })?.urlString
		root.bar.didSwitch(to: id, urlString: urlString)
	}
	func closeTab(_ id: UUID) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before closeTab(id=\(id.uuidString)) activeTabID=\(activeTabID?.uuidString ?? "nil") leftTabID=\(leftTabID?.uuidString ?? "nil") rightTabID=\(rightTabID?.uuidString ?? "nil")",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.handleTabClosed(id)
	}
	func moveTab(from: Int, to: Int) {
		// Delegate via SplitBrowserViewModel API, not stores directly.
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before moveTab(from=\(from), to=\(to)) activeTabID=\(activeTabID?.uuidString ?? "nil")",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.moveTab(from: from, to: to)
	}
	func removeAllTabs() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before removeAllTabs activeTabID=\(activeTabID?.uuidString ?? "nil")",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		let ids = root.tabManager.tabs.map { $0.id }
		for id in ids {
			root.tabManager.closeTab(id)
		}
	}
	// MARK: - Tab groups
	func createTabGroup(name: String, color: BrowserTabGroup.TabGroupColor? = nil) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before createTabGroup(name=\(name))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.createTabGroup(name, color: color)
	}
	func selectTabGroup(_ id: UUID?) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before selectTabGroup(id=\(id?.uuidString ?? "nil"))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		if let id { root.tabManager.selectTabGroup(id) }
	}
	func deleteTabGroup(_ id: UUID) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before deleteTabGroup(id=\(id.uuidString))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.deleteTabGroup(id)
	}
	func updateTabGroup(id: UUID, name: String, color: BrowserTabGroup.TabGroupColor? = nil) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before updateTabGroup(id=\(id.uuidString), name=\(name))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.updateTabGroup(id, name: name, color: color)
	}
	func addTabToGroup(tabID: UUID, groupID: UUID) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserTabsDomain: root nil before addTabToGroup(tabID=\(tabID.uuidString), groupID=\(groupID.uuidString))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.addTabToGroup(tabID, groupID: groupID)
	}
}

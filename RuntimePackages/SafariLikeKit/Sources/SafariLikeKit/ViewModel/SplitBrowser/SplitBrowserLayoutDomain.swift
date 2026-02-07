import Foundation
import Combine
import CoreGraphics
import SafariLikeCoreKit
@MainActor
final class SplitBrowserLayoutDomain: ObservableObject {
	// Layout-related state previously in ViewModel
	private weak var root: SplitBrowserViewModel?
	@Published var activePane: SplitBrowserViewModel.ActivePane = .left
	// Computed layout flags and ratios mapped to root state
	var isSplit: Bool { root?.tabManager.isSplitViewEnabled ?? false }
	var isPortrait: Bool { !(root?.isLandscapeDevice ?? true) }
	var paneRatio: CGFloat { root?.tabManager.splitViewRatio ?? 0.5 }
	var isShowingSecondPane: Bool {
		return isSplit && root?.tabManager.rightTabID != nil
	}
	init(root: SplitBrowserViewModel) { self.root = root }
	// Toggle split layout
	func toggleSplit() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserLayoutDomain: root nil before toggleSplit(activePane=\(String(describing: activePane)))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.toggleSplitView()
	}
	// Enable/disable split
	func setSplit(_ enabled: Bool) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserLayoutDomain: root nil before setSplit(enabled=\(enabled) activePane=\(String(describing: activePane)))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		if enabled { root.tabManager.enableSplitView() }
		else { root.tabManager.disableSplitView() }
	}
	// Switch active pane
	func switchPane(_ pane: SplitBrowserViewModel.ActivePane) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserLayoutDomain: root nil before switchPane(pane=\(String(describing: pane)) currentActivePane=\(String(describing: activePane)))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		activePane = pane
		switch pane {
		case .left: root.tabManager.selectLeftPane()
		case .right: root.tabManager.selectRightPane()
		}
	}
	func selectLeftPane() { switchPane(.left) }
	func selectRightPane() { switchPane(.right) }
	// Switch to the other pane (no-arg convenience)
	func switchPane() {
		let next: SplitBrowserViewModel.ActivePane = (activePane == .left) ? .right : .left
		switchPane(next)
	}
	// Update the layout; placeholder to refresh derived UI if needed
	func updateLayout() {
		// Currently derived from TabManager + orientation; left as a hook.
	}
	// Handle rotation changes and apply orientation policies
	func handleRotation(isLandscape: Bool) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserLayoutDomain: root nil before handleRotation(isLandscape=\(isLandscape))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.applyOrientationRule(isLandscape: isLandscape)
	}
	// Update pane width ratio (0...1)
	func updatePaneWidth(ratio: CGFloat) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserLayoutDomain: root nil before updatePaneWidth(ratio=\(ratio))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.tabManager.splitViewRatio = max(0.0, min(1.0, ratio))
	}
}

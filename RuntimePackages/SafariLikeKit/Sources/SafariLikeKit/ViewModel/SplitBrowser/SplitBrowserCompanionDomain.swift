import Foundation
import SafariLikeCoreKit
import Combine
import CoreGraphics
import SwiftUI
import os
@MainActor
final class SplitBrowserCompanionDomain: ObservableObject {
	private let logger = Logger(subsystem: "SafariLikeKit", category: "SplitBrowserCompanionDomain")
	// Companion-related state and proxies moved from SplitBrowserViewModel
	// Proxies keep API stable while logic migrates into this domain.
	weak var root: SplitBrowserViewModel?
	init(root: SplitBrowserViewModel) { self.root = root }
	private func withRoot<T>(_ block: (SplitBrowserViewModel) -> T) -> T? {
		guard let root else { return nil }
		return block(root)
	}
	// Flags
	var isAutoCompanionEnabled: Bool {
		get { withRoot { $0.isAutoCompanionEnabled } ?? true }
		set { withRoot { $0.setAutoCompanionEnabled(newValue) } }
	}
	var isCompanionVisible: Bool {
		get { withRoot { $0.isCompanionVisible } ?? false }
		set {
			withRoot { root in
				root.mutateAsync {
					root.isCompanionVisible = newValue
				}
			}
		}
	}
	var isRelatedVisible: Bool {
		get { withRoot { $0.isRelatedVisible } ?? false }
		set {
			withRoot { root in
				root.mutateAsync {
					root.isRelatedVisible = newValue
				}
			}
		}
	}
	var isLandscapeSplitActive: Bool {
		get { withRoot { $0.isLandscapeSplitActive } ?? false }
		set {
			withRoot { root in
				root.mutateAsync {
					root.isLandscapeSplitActive = newValue
				}
			}
		}
	}
	var didUserOverrideCompanionVisibility: Bool {
		get { withRoot { $0.didUserOverrideCompanionVisibility } ?? false }
		set {
			withRoot { root in
				root.mutateAsync {
					root.didUserOverrideCompanionVisibility = newValue
				}
			}
		}
	}
	// Ratios
	var splitRatio: CGFloat {
		get { withRoot { $0.splitRatio } ?? SplitBrowserConstants.defaultSplitRatio }
		set {
			withRoot { root in
				root.mutateAsync {
					root.splitRatio = newValue
				}
			}
		}
	}
	var relatedPopupHeightFraction: CGFloat {
		get { withRoot { $0.relatedPopupHeightFraction } ?? SplitBrowserConstants.relatedSnapMid }
		set {
			withRoot { root in
				root.mutateAsync {
					root.relatedPopupHeightFraction = newValue
				}
			}
		}
	}
	// Presentation & animation
	var relatedPresentationProxy: SplitBrowserViewModel.RelatedPresentation {
		get { withRoot { $0.relatedPresentation } ?? .hidden }
		set {
			withRoot { root in
				root.mutateAsync {
					root.relatedPresentation = newValue
				}
			}
		}
	}
	var relatedAnimationProxy: Animation? {
		get { withRoot { $0.relatedAnimation } ?? .easeOut(duration: 0.25) }
		set {
			withRoot { root in
				root.mutateAsync {
					root.relatedAnimation = newValue
				}
			}
		}
	}
	// Orientation
	var isLandscapeDevice: Bool {
		get { withRoot { $0.isLandscapeDevice } ?? false }
		set {
			withRoot { root in
				root.mutateAsync {
					root.isLandscapeDevice = newValue
				}
			}
		}
	}
	// Companion items feed (read-only)
	var companionItems: [CompanionItem] { withRoot { $0.companionItems } ?? [] }
	// MARK: - Actions
	func toggleCompanion() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before toggleCompanion",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.send(.toggleRelated)
	}
	// MARK: - Orientation rule
	func applyOrientationRule(isLandscape: Bool) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before applyOrientationRule(isLandscape=\(isLandscape))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.mutateAsync {
			root.isLandscapeSplitActive = isLandscape
			root.isLandscapeDevice = isLandscape
		}
		root.companionController.isAutoCompanionEnabled = root.isAutoCompanionEnabled
		root.companionController.didUserOverrideCompanionVisibility = root.didUserOverrideCompanionVisibility
		root.companionController.applyOrientationRule(isLandscape: isLandscape)
		root.companionController.updateCompanionItems(empty: root.companionItems.isEmpty)
	}
	// MARK: - Presentation
	func setPresentation(_ presentation: SplitBrowserViewModel.RelatedPresentation) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before setPresentation(\(String(describing: presentation)))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.mutateAsync {
			root.relatedPresentation = presentation
		}
		root.companionController.isLandscapeDevice = root.isLandscapeDevice
		root.companionController.isAutoCompanionEnabled = root.isAutoCompanionEnabled
		root.companionController.didUserOverrideCompanionVisibility = root.didUserOverrideCompanionVisibility
		root.companionController.updateCompanionItems(empty: root.companionItems.isEmpty)
		root.companionController.setPresentation(presentation)
	}
	func destroyRightPaneForRoot() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before destroyRightPaneForRoot",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.mutateAsync {
			root.relatedAnimation = nil
		}
		root.companionController.relatedAnimation = nil
		root.companionController.setPresentation(.hidden)
	}
	func resetCompanionOverride() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before resetCompanionOverride",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.mutateAsync {
			root.didUserOverrideCompanionVisibility = false
		}
	}
	// Open items
	func openCompanionItem(_ item: CompanionItem) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before openCompanionItem(title=\(item.title), urlString=\(item.urlString))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.navigationService.loadURLString(item.urlString, force: true)
		root.activePane = .left
	}
	func openCompanionItemInNewTab(_ item: CompanionItem) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before openCompanionItemInNewTab(title=\(item.title), urlString=\(item.urlString))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		let urlString = item.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		guard urlString.isEmpty == false else { return }
		#if DEBUG
		let beforeActiveTabID = root.activeTabID
		let beforeSelectedTabID = root.sessionStore.selectedTabID
		let beforeActivePane = root.activePane
		print("[Related][OpenInNewTab] BEFORE activeTabID=\(String(describing: beforeActiveTabID)) selectedTabID=\(String(describing: beforeSelectedTabID)) activePane=\(beforeActivePane)")
		#endif
		// Safari-like: "Open in New Tab" from Related must NOT steal focus.
		// - Create a background tab via the normal VM tabs API and capture its tabID.
		// - Update session metadata for that new tab.
		// - Do NOT call navigationService.loadURLString(...) for background (would hit active tab).
		// - Do NOT mutate activePane.
		let newTabID = root.openTabReturningID(urlString: urlString, inBackground: true)
		root.updateTab(id: newTabID, title: item.title, urlString: urlString)
		#if DEBUG
		let afterActiveTabID = root.activeTabID
		let afterSelectedTabID = root.sessionStore.selectedTabID
		let afterActivePane = root.activePane
		print("[Related][OpenInNewTab] AFTER  newTabID=\(newTabID) activeTabID=\(String(describing: afterActiveTabID)) selectedTabID=\(String(describing: afterSelectedTabID)) activePane=\(afterActivePane)")
		#endif
	}
	// Quick open/close helpers for common companion sections
	func openBookmarks() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before openBookmarks",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.activePane = .left
		root.activeCompanionSection = .bookmarks
	}
	func openHistory() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before openHistory",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.activePane = .left
		root.activeCompanionSection = .history
	}
	func openDownloads() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before openDownloads",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.activePane = .left
		root.activeCompanionSection = .downloads
	}
	func closeCompanion() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserCompanionDomain: root nil before closeCompanion",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.activeCompanionSection = nil
	}
}

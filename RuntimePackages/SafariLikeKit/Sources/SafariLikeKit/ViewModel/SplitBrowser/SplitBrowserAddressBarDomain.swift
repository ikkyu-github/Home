import Foundation
import Combine
import UIKit
import SafariLikeCoreKit
import SafariLikeUXKit
import SafariLikeContracts
#if DEBUG
import OSLog
#endif
// Moved UI state machine + state/events to SafariLikeUXKit.
@MainActor
final class SplitBrowserAddressBarDomain: ObservableObject {
	#if DEBUG
	private static let omniboxLogger = Logger(subsystem: "SafariLikeKit", category: "Omnibox")
	#endif

	enum EditingDismissalIntent: String {
		case cancel
		case commit
	}

	// MARK: - Mutation Boundary
	@MainActor
	private func deferStateMutation(_ block: @escaping @MainActor () -> Void) {
		Task { @MainActor in
			await Task.yield()
			block()
		}
	}
	private func mutate(_ block: () -> Void) {
		block()
	}
	private func mutateAsync(_ block: @escaping () -> Void) {
		deferStateMutation {
			block()
		}
	}
	// Address bar state moved from SplitBrowserViewModel
	@Published private(set) var addressText: String = ""
	@Published private(set) var isAddressFocusedExternally: Bool = false
	@Published private(set) var addressBarState: AddressBarUIState = .idle(urlDisplayed: "", security: .unknown)
	private var feature: SafariLikeUXKit.AddressBarFeature
	weak var root: SplitBrowserViewModel?
	private let perTabStateStore = AddressBarTabStateStore()
	init(root: SplitBrowserViewModel, initialURLString: String) {
		self.root = root
		self.feature = SafariLikeUXKit.AddressBarFeature(initialURLString: initialURLString)
		let snapshot = self.feature.snapshot()
		mutate {
			self.addressBarState = snapshot.state
			self.addressText = snapshot.committedURLString
			self.isAddressFocusedExternally = snapshot.state.isTextInputFocused
		}
	}
	// MARK: - State machine API (View must send events; never mutate state directly)
	func send(_ event: SafariLikeContracts.AddressBarEvent) {
		// Defer all @Published writes out of SwiftUI view update callbacks.
		mutateAsync { [weak self] in
			self?.apply(event)
		}
	}

	// Legacy internal API (avoid migrating all runtime callers at once).
	func send(_ event: SafariLikeUXKit.AddressBarUIEvent) {
		send(event.asContractsEvent)
	}

	/// Single entry point for ending omnibox editing.
	/// - cancel: Safari-like cancel (restores last committed URL)
	/// - commit: dismiss focus without canceling draft (used after submit)
	func dismissEditing(intent: EditingDismissalIntent, reason: String) {
		mutateAsync { [weak self] in
			guard let self else { return }
			guard self.addressBarState.isTextInputFocused else {
				#if DEBUG
				Self.omniboxLogger.debug("dismissEditing ignored (not focused) intent=\(intent.rawValue, privacy: .public) reason=\(reason, privacy: .public)")
				#endif
				return
			}
			#if DEBUG
			Self.omniboxLogger.debug("dismissEditing begin intent=\(intent.rawValue, privacy: .public) reason=\(reason, privacy: .public) state=\(String(describing: self.addressBarState), privacy: .public)")
			#endif
			switch intent {
			case .cancel:
				self.apply(.cancelEditing)
			case .commit:
				self.apply(.focusChanged(isFocused: false))
			}
			#if DEBUG
			if self.addressBarState.isTextInputFocused {
				Self.omniboxLogger.error("dismissEditing ended but still focused (POSSIBLE STUCK EDITING) intent=\(intent.rawValue, privacy: .public) reason=\(reason, privacy: .public) state=\(String(describing: self.addressBarState), privacy: .public)")
			} else {
				Self.omniboxLogger.debug("dismissEditing end intent=\(intent.rawValue, privacy: .public) reason=\(reason, privacy: .public)")
			}
			#endif
		}
	}

	/// Submit the current omnibox entry, then deterministically exit editing.
	func submitAndDismissEditing(reason: String) {
		mutateAsync { [weak self] in
			guard let self else { return }
			#if DEBUG
			Self.omniboxLogger.debug("submitAndDismissEditing begin reason=\(reason, privacy: .public) state=\(String(describing: self.addressBarState), privacy: .public)")
			#endif
			self.apply(.submitAndDismissEditing)
			#if DEBUG
			if self.addressBarState.isTextInputFocused {
				Self.omniboxLogger.error("submitAndDismissEditing ended but still focused (POSSIBLE STUCK EDITING) reason=\(reason, privacy: .public) state=\(String(describing: self.addressBarState), privacy: .public)")
			} else {
				Self.omniboxLogger.debug("submitAndDismissEditing end reason=\(reason, privacy: .public)")
			}
			#endif
		}
	}
	func onNavigationCommitted(urlString: String) {
		send(SafariLikeContracts.AddressBarEvent.navigationCommitted(urlString: urlString))
	}
	func onLoadingChanged(isLoading: Bool, progress: Double) {
		send(SafariLikeContracts.AddressBarEvent.loadingChanged(isLoading: isLoading, progress: progress))
	}
	private func apply(_ event: SafariLikeContracts.AddressBarEvent) {
		let previousFocus = isAddressFocusedExternally
		var nextUIState = addressBarState
		let effects = feature.reduce(state: &nextUIState, event: event)
		if addressBarState != nextUIState {
			mutate {
				addressBarState = nextUIState
			}
		}
		syncDerivedMirrors(previousFocus: previousFocus)
		execute(effects)
	}

	private func syncDerivedMirrors(previousFocus: Bool) {
		let shouldBeFocused = addressBarState.isTextInputFocused
		if isAddressFocusedExternally != shouldBeFocused {
			mutate {
				isAddressFocusedExternally = shouldBeFocused
			}
		}
		if previousFocus != shouldBeFocused {
			deferStateMutation { [weak root] in
				root?.chrome.setAddressFocused(shouldBeFocused)
			}
		}
		let committed = feature.snapshot().committedURLString
		let nextAddressText = shouldBeFocused ? addressBarState.textFieldText : committed
		if addressText != nextAddressText {
			mutate {
				addressText = nextAddressText
			}
		}
	}

	private func execute(_ effects: [SafariLikeUXKit.AddressBarEffect]) {
		guard let root else { return }
		for effect in effects {
			switch effect {
			case .openURLString(let s, let force):
				root.addressBar.openURLString(s, force: force)
			case .search(let q):
				root.addressBar.loadSearch(query: q)
			case .cancel:
				root.addressBar.cancel()
			@unknown default:
				break // fallback: do nothing
			}
		}
	}
	// MARK: - Tab switch (per-tab state)
	func willSwitch(from oldTabID: UUID?) {
		guard let oldTabID else { return }
		perTabStateStore.save(tabID: oldTabID, snapshot: feature.snapshot())
	}
	func didSwitch(to newTabID: UUID, urlString: String?) {
		mutateAsync { [weak self] in
			guard let self else { return }
			if let saved = self.perTabStateStore.snapshot(for: newTabID) {
				self.feature.restore(saved)
			} else {
				self.feature = SafariLikeUXKit.AddressBarFeature(initialURLString: urlString ?? "")
			}
			let snapshot = self.feature.snapshot()
			self.mutate {
				self.addressBarState = snapshot.state
			}
			self.syncDerivedMirrors(previousFocus: self.isAddressFocusedExternally)
		}
	}
	func submitAddress() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before submitAddress(addressText=\(addressText), focusedExternally=\(isAddressFocusedExternally))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		// Delegate to the runtime controller so we preserve normalization,
		// session store sync, and submit locking.
		root.addressBar.openURLString(addressText, force: false)
	}
	// MARK: - External open
	func openExternalURL(_ url: URL) {
		// Delegate to runtime controller
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before openExternalURL(url=\(url.absoluteString))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.addressBar.openExternalURL(url)
	}
	// MARK: - Suggestions
	func updateSuggestions(query: String) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before updateSuggestions(query=\(query))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.addressBar.updateSuggestions(query: query)
	}
	func clearSuggestions() {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before clearSuggestions(addressText=\(addressText))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.addressBar.clearSuggestions()
	}
	func applySuggestion(_ suggestion: SplitBrowserViewModel.OmniboxSuggestion) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before applySuggestion(title=\(suggestion.title), kind=\(String(describing: suggestion.kind)))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.addressBar.applySuggestion(suggestion)
	}
	// MARK: - Search routing
	func loadSearch(query: String) {
		guard let root else {
			Diagnostics.logError(
				"SplitBrowserAddressBarDomain: root nil before loadSearch(query=\(query))",
				subsystem: .runtime,
				category: "SplitBrowserDomain"
			)
			return
		}
		root.addressBar.loadSearch(query: query)
	}
	// MARK: - Focus
	func requestAddressFocus() {
		// Focus is UI-state-driven: dispatch to the reducer.
		send(SafariLikeContracts.AddressBarEvent.tapAddressBar)
	}
}

private extension SafariLikeUXKit.AddressBarUIEvent {
	var asContractsEvent: SafariLikeContracts.AddressBarEvent {
		switch self {
		case .tapAddressBar: return .tapAddressBar
		case .focusChanged(let isFocused): return .focusChanged(isFocused: isFocused)
		case .textChanged(let s): return .textChanged(s)
		case .submit: return .submit
		case .navigationCommitted(let urlString): return .navigationCommitted(urlString: urlString)
		case .loadingChanged(let isLoading, let progress):
			return .loadingChanged(isLoading: isLoading, progress: progress)
		case .tapLockIcon: return .tapLockIcon
		case .tapOutside: return .tapOutside
		case .dismissSecurityInfo: return .dismissSecurityInfo
		case .clearText: return .clearText
		@unknown default:
			return .tapAddressBar // fallback: safe default
		}
	}
}

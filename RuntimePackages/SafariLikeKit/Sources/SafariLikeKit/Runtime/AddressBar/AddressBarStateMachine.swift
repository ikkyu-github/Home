import SafariLikeUXKit
import SafariLikeCoreKit
/// Shim kept for source compatibility.
/// Implementation moved to SafariLikeUXKit as a generic, model-agnostic state machine.
typealias AddressBarStateMachine = AddressBarEntryStateMachine<SplitBrowserViewModel.OmniboxSuggestion>

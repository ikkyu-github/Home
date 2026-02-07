import Foundation

/// UI/runtime-facing WebView performance tier.
///
/// This is a policy-level type intended for higher layers (e.g. SafariLikeKit)
/// to express how aggressively a tab should consume WebView resources.
@MainActor
public enum WebViewPerformanceTier: Sendable, Equatable {
	/// Active/primary tab.
	case foreground
	/// Visible but not primary (e.g. split companion / preview).
	case backgroundVisible
	/// Not visible; should not consume foreground resources.
	case backgroundHidden

	@inline(__always)
	internal var tabPriority: TabPriority {
		switch self {
		case .foreground:
			return .foreground
		case .backgroundVisible, .backgroundHidden:
			return .background
		}
	}
}

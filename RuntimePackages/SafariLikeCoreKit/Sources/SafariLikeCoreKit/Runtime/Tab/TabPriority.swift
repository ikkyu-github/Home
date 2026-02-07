import Foundation

/// Coarse tab priority model used to tune WebView leasing and memory behavior.
///
/// Intended semantics:
/// - `foreground`: active/visible tab(s); should keep a live WKWebView for snappy UX.
/// - `background`: not visible; should detach from UI and return its lease to the pool.
/// - `discarded`: under memory pressure / large tab count; WKWebView should be destroyed,
///   but restore state should remain (no unnecessary reload beyond normal restore).
public enum TabPriority: Sendable, Equatable {
    case foreground
    case background
    case discarded
}

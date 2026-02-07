import Foundation

/// Address bar core UX state (Safari-like, deterministic).
///
/// Notes:
/// - `idle` shows the simplified URL.
/// - `focused` represents focused-without-user-editing-yet (tap selects all).
/// - `editing` is user editing raw text.
/// - `searching` is after submit of a non-URL query (until navigation commit).
/// - `navigating` is after submit of a URL (until navigation commit).
public enum AddressBarState: Sendable, Equatable {
    case idle(url: URL?)
    case focused(url: URL?)

    /// `baseURL` is the last committed URL at the moment editing began.
    /// Used to support Safari-like cancel/blur restore behavior.
    case editing(text: String, baseURL: URL?)

    /// `baseURL` is the last committed URL at the moment searching began.
    case searching(query: String, baseURL: URL?)

    case navigating(url: URL?)

    public var committedURL: URL? {
        switch self {
        case .idle(let url), .focused(let url), .navigating(let url):
            return url
        case .editing(_, let baseURL), .searching(_, let baseURL):
            return baseURL
        }
    }

    public var isFocused: Bool {
        switch self {
        case .focused, .editing, .searching:
            return true
        case .idle, .navigating:
            return false
        }
    }

    public var draftText: String? {
        switch self {
        case .editing(let text, _):
            return text
        case .searching(let query, _):
            return query
        case .focused(let url):
            return url?.absoluteString ?? ""
        case .idle, .navigating:
            return nil
        }
    }
}

public enum AddressBarAction: Sendable, Equatable {
    case focus
    case blur
    case inputChanged(String)
    case submit
    case navigationCommitted(URL?)
    case cancel
}

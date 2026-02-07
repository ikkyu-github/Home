import Foundation

public enum OmnibarState: Equatable {
    case collapsed(showURL: Bool)
    case focused(editingText: String, selection: Range<Int>?)
    case showingSuggestions(query: String)
    case navigating(pendingURL: URL)
    case loading(progress: Double)
    case displayingSecurity(origin: String, isSecure: Bool)
}

public enum OmnibarEvent: Equatable {
    case onTapBar
    case onBeginEditing(text: String)
    case onTextChange(text: String)
    case onSubmit(text: String)
    case onCancel
    case onNavigationCommit(url: URL)
    case onLoadProgress(progress: Double)
    case onScroll(offset: Double)
    case onFocusChanged(isFocused: Bool)
    case onSecurity(origin: String, isSecure: Bool)
}

public struct OmnibarStateMachine: Equatable {
    public private(set) var state: OmnibarState

    public init(initial: OmnibarState = .collapsed(showURL: true)) {
        self.state = initial
    }

    public mutating func handle(_ event: OmnibarEvent) {
        state = OmnibarStateMachine.reduce(state: state, event: event)
    }

    public static func reduce(state: OmnibarState, event: OmnibarEvent) -> OmnibarState {
        switch (state, event) {
        case (_, .onTapBar):
            switch state {
            case .focused, .showingSuggestions:
                return state
            default:
                return .focused(editingText: "", selection: nil)
            }

        case (_, .onBeginEditing(let text)):
            return .focused(editingText: text, selection: nil)

        case (.focused(_, _), .onTextChange(let text)):
            let t = text
            if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .focused(editingText: t, selection: nil)
            }
            return .showingSuggestions(query: t)

        case (.showingSuggestions, .onTextChange(let text)):
            let t = text
            if t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .focused(editingText: t, selection: nil)
            }
            return .showingSuggestions(query: t)

        case (_, .onSubmit(let text)):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmed), url.scheme != nil {
                return .navigating(pendingURL: url)
            }
            if let url = URL(string: "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)") {
                return .navigating(pendingURL: url)
            }
            return .collapsed(showURL: true)

        case (_, .onCancel):
            return .collapsed(showURL: true)

        case (_, .onFocusChanged(let isFocused)):
            if isFocused {
                switch state {
                case .focused, .showingSuggestions:
                    return state
                default:
                    return .focused(editingText: "", selection: nil)
                }
            } else {
                return .collapsed(showURL: true)
            }

        case (_, .onNavigationCommit(let url)):
            // Preserve committed origin for follow-up security UI.
            return .displayingSecurity(origin: url.host ?? url.absoluteString, isSecure: (url.scheme?.lowercased() == "https"))

        case (.loading, .onLoadProgress(let p)):
            let clamped = min(max(p, 0), 1)
            if clamped >= 1 {
                return .collapsed(showURL: true)
            }
            return .loading(progress: clamped)

        case (_, .onSecurity(let origin, let isSecure)):
            return .displayingSecurity(origin: origin, isSecure: isSecure)

        case (_, .onScroll(let offset)):
            let showURL = offset < 8
            switch state {
            case .loading:
                return .collapsed(showURL: showURL)
            case .collapsed:
                return .collapsed(showURL: showURL)
            default:
                return state
            }

        default:
            return state
        }
    }
}

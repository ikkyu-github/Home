import Foundation
import SafariLikeContracts

public struct AddressBarReducer: Sendable {
    public init() {}

    public enum Submission: Sendable, Equatable {
        case empty
        case url
        case search
    }

    public static func classifySubmission(_ text: String) -> Submission {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return .empty }
        if looksLikeURL(trimmed) { return .url }
        return .search
    }

    public func reduce(state: AddressBarState, action: AddressBarAction) -> AddressBarState {
        switch (state, action) {
        case (.idle(let url), .focus):
            return .focused(url: url)

        case (.focused(let url), .focus):
            return .focused(url: url)

        case (.editing(let text, let baseURL), .focus):
            return .editing(text: text, baseURL: baseURL)

        case (.searching(let query, let baseURL), .focus):
            return .searching(query: query, baseURL: baseURL)

        case (.navigating(let url), .focus):
            return .focused(url: url)

        case (.focused(let url), .inputChanged(let text)):
            return .editing(text: text, baseURL: url)

        case (.idle(let url), .inputChanged(let text)):
            // Defensive: if input arrives while idle, treat as editing.
            return .editing(text: text, baseURL: url)

        case (.editing(_, let baseURL), .inputChanged(let text)):
            return .editing(text: text, baseURL: baseURL)

        case (.searching(_, let baseURL), .inputChanged(let text)):
            // User edits again while we consider ourselves "searching".
            return .editing(text: text, baseURL: baseURL)

        case (.navigating(let url), .inputChanged(let text)):
            return .editing(text: text, baseURL: url)

        case (.editing(let text, let baseURL), .submit):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                return .editing(text: text, baseURL: baseURL)
            }

            if Self.looksLikeURL(trimmed) {
                // Do not attempt to normalize here; runtime navigation will.
                return .navigating(url: URL(string: trimmed) ?? baseURL)
            }

            return .searching(query: trimmed, baseURL: baseURL)

        case (.focused(let url), .submit):
            // Safari: submit while focused but unchanged => reload/navigate to same URL.
            return .navigating(url: url)

        case (.idle(let url), .submit):
            return .idle(url: url)

        case (.searching(let query, let baseURL), .submit):
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return .searching(query: query, baseURL: baseURL) }
            return .searching(query: trimmed, baseURL: baseURL)

        case (.navigating(let url), .submit):
            return .navigating(url: url)

        case (_, .navigationCommitted(let url)):
            switch state {
            case .navigating:
                // Navigation driven by the address bar finishes -> idle.
                return .idle(url: url)

            case .idle:
                return .idle(url: url)

            case .focused:
                // Keep focus, but update committed URL.
                return .focused(url: url)

            case .editing(let text, let baseURL):
                // Do not clobber the draft; keep baseURL stable.
                return .editing(text: text, baseURL: baseURL)

            case .searching(let query, let baseURL):
                // Do not clobber the query; keep baseURL stable.
                return .searching(query: query, baseURL: baseURL)

            @unknown default:
                return .idle(url: url)
            }

        case (.focused(let url), .cancel), (.focused(let url), .blur):
            return .idle(url: url)

        case (.editing(_, let baseURL), .cancel), (.editing(_, let baseURL), .blur):
            return .idle(url: baseURL)

        case (.searching(_, let baseURL), .cancel), (.searching(_, let baseURL), .blur):
            return .idle(url: baseURL)

        case (.idle(let url), .cancel), (.idle(let url), .blur):
            return .idle(url: url)

        case (.navigating(let url), .cancel), (.navigating(let url), .blur):
            // Blur/cancel during navigation should not lose the URL.
            return .idle(url: url)

        @unknown default:
            // Forward-compat: preserve state for unknown future cases.
            return state
        }
    }

    private static func looksLikeURL(_ text: String) -> Bool {
        // Simple Safari-like heuristic:
        // - contains a dot without spaces OR has a scheme.
        // - reject plain words ("apple") as search.
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.isEmpty == false else { return false }
        if t.contains(" ") { return false }
        if let url = URL(string: t), let scheme = url.scheme, scheme.isEmpty == false {
            return true
        }
        return t.contains(".")
    }
}
